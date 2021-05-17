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

  - `bot_token`: your Telegram bot tokent
  - `conversations`: keyword list of name and chat_id. There must be at least 1 conversation which is `:default`. `default` is used if you don't specify conversation name in the function call.

  Then you are ready to send message to your Telegram conversation
  """

  require Logger

  @doc """
  This macro help you to catch exceptions and then send to your Telegram conversation using `send_error/4`

  ## Options
  - `to`: conversation name from your config. Default is `:default`
  - `args`: argument list that passed to function, this is sent to telegram chat for dev to debug easier. If not speficied, arguments for current function call are used
  - `label`: label for this error/function. If not specified, current function name is used.

  **Example**
      ...
      require Magik.TelegramNoti

      def do_something(args) do
        Magik.TelegramNoti.watch [to: :admin] do
            # your logic code here
        end
      end
      ...
  """
  defmacro watch(opts \\ [], do: block) do
    quote do
      try do
        unquote(block)
      rescue
        err ->
          conversation = Keyword.get(unquote(opts), :to, :default)
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

  @doc """
  Send a message to conversation

      send_message(:api, "this is a sample message")
  """
  @spec send_message(atom, String.t()) :: {:ok, map} | {:error, map}
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

  @doc """
  Format and send error message to a Telegam conversation with data from a connection. This helper is used to send error from your phoenix router or controller.


  ## From router
      defmodule MyApp.Router do
          use MyAppWeb, :router
          use Plug.ErrorHandler
          ...

          def handle_errors(conn, error) do
              if conn.status >= 500 do
                   Magik.TelegramNoti.send_conn_error(:api, conn, error)
              end
              ....
         end
      end


  ## from controller
      defmodule MyAppWeb.PageController do
          ...
          def index(conn, params)do
            try do
                ...
            catch
              error ->
                 Magik.TelegramNoti.send_conn_error(:api, conn, %{kind: :error, reason: error, stack: __STACKTRACE__})
                 # return your error
            end
          end
      end

  """
  @spec send_conn_error(atom, Plug.Conn.t(), map) :: {:ok, map} | {:error, map}
  def send_conn_error(conversation \\ :default, %{} = conn, %{
        kind: kind,
        reason: reason,
        stack: stacktrace
      }) do
    message = """
    *ERROR: #{conn.private[:phoenix_controller]}.#{conn.private[:phoenix_action]}*
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

  @doc """
  Format error and send to Telegram conversation.

      defmodule MyApp.Calculator do
          ...
          def divide(a, b)do
              try do
                  ...
              catch
                  error ->
                      Magik.TelegramNoti.send_error(:api, "MyApp.Calculator error", [a,b], %{kind: :error, reason: error, stack: __STACKTRACE__})
                      # return your error
              end
          end
      end
  """
  @spec send_error(atom, String.t(), any, map) :: {:ok, map} | {:error, map}
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
