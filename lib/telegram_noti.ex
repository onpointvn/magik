defmodule Magik.TelegramNoti do
  @moduledoc """
  This module provide some helper functions that help to send message to a telegram conversation

  ## Config
      config :magik, :telegram_noti,
          bot_token: "your bot token".
          conversations: [
                default: "default_chat_id",
                admin: "other chat id"
            ],
          mode: :prod # or :dev

  - `conversations` is a keyword list with name and chat_id
  - `mode`: `:prod` or `:dev` is used in TelegramNoti Plug, if `mode == :dev` then reraise the error and return error stacktrace to client side. If `mode == :prod` then do not return error stacktrace.
  """

  require Logger

  @doc """
  Watch a function and send notification to conversation if an exception occurs

  ## Options
  - `to`: conversation name
  - `args`: argument list that passed to function, this is sent to telegram chat for dev to debug easier
  - `label`: Label for this error/function

  **Example**
      ...
      def do_something(args) do
        
      end
      ...
  """
  defmacro watch(opts \\ [], do: block) do
    quote do
      try do
        unquote(block)
      rescue
        err ->
          conversation = Keyword.get(unquote(opts), :to)
          label = Keyword.get(unquote(opts), :label)

          label =
            if label do
              label
            else
              {mod_name, func_name, arity, _} =
                Process.info(self(), :current_stacktrace)
                |> elem(1)
                |> Enum.fetch!(2)

              "#{mod_name}.#{func_name}/#{arity}"
            end

          Magik.TelegramNoti.send_error(conversation, label, binding(), %{
            kind: :error,
            reason: err,
            stack: __STACKTRACE__
          })

          :erlang.raise(:error, err, __STACKTRACE__)
      end
    end
  end

  def send_message(conversation \\ :default, message) do
    config = Application.get_env(:magik, :telegram_noti, [])

    with conversations <- config[:conversations],
         chat_id <- Keyword.get(conversations || [], conversation),
         false <- chat_id in [nil, ""],
         false <- config[:bot_token] in [nil, ""] do
      url = "https://api.telegram.org/bot#{config[:bot_token]}/sendMessage"

      data =
        Jason.encode!(%{
          "chat_id" => chat_id,
          "text" => escape_message(message),
          "disable_web_page_preview" => true,
          "parse_mode" => "MarkdownV2"
        })

      Tesla.post(
        url,
        data,
        headers: [{"content-type", "application/json"}]
      )
    else
      _ -> Logger.error("Telegram Noti: Missing chat_id/bot_token configuration")
    end
  end

  def send_conn_error(conversation \\ :default, %{} = conn, %{
        kind: kind,
        reason: reason,
        stack: stacktrace
      }) do
    message = """
    *ERROR: #{inspect(reason)}*
    --------------------

    *Request URL*: #{Phoenix.Controller.current_url(conn)}

    *Request Params*:
    ```
    #{inspect(conn.params, pretty: true)}
    ```

    *Details*
    ```
    #{Exception.format(kind, reason, stacktrace)}
    ```
    """

    send_message(conversation, message)
  end

  def send_error(conversation \\ :default, title, args \\ nil, %{
        kind: kind,
        reason: reason,
        stack: stacktrace
      }) do
    message = """
    *ERROR: #{title}*
    ----------------

    *Params*:
    ```
    #{inspect(args, pretty: true)}
    ```

    *Details*
    ```
    #{Exception.format(kind, reason, stacktrace)}
    ```
    """

    send_message(conversation, message)
  end

  defp escape_message(message) do
    message
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace(".", "\\.")
    |> String.replace("-", "\\-")
    |> String.replace("_", "\\_")

    # |> String.replace("*", "\\*")
    # |> String.replace("[", "\\[")
    # |> String.replace("`", "\\`")
  end
end
