defmodule Magik.Plug.TelegramNoti do
  @moduledoc """
  This Plug automatically handle exception and send detail to Telegram conversation

  In your router add this line

      if Mix.env() != :dev do
          use Magik.Plug.TelegramNoti, to: :admin
      end

  **Options**
  - `to`: your conversation name
  """

  defmacro __using__(opts \\ []) do
    conversation = Keyword.get(opts, :to)

    quote location: :keep do
      require Logger
      @before_compile Magik.Plug.TelegramNoti

      @doc false
      def handle_errors(conn, %{kind: kind, reason: reason, stack: stacktrace} = error) do
        Logger.error(Exception.format(kind, reason, stacktrace))
        Magik.TelegramNoti.send_conn_error(unquote(conversation), conn, error)
        Plug.Conn.send_resp(conn, conn.status, "Something went wrong")
      end

      defoverridable handle_errors: 2
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote location: :keep do
      defoverridable call: 2

      def call(conn, opts) do
        try do
          super(conn, opts)
        rescue
          e in Plug.Conn.WrapperError ->
            %{conn: conn, kind: kind, reason: reason, stack: stack} = e
            Magik.Plug.TelegramNoti.__catch__(conn, kind, e, reason, stack, &handle_errors/2)
        catch
          kind, reason ->
            Magik.Plug.TelegramNoti.__catch__(
              conn,
              kind,
              reason,
              reason,
              __STACKTRACE__,
              &handle_errors/2
            )
        end
      end
    end
  end

  @already_sent {:plug_conn, :sent}

  @doc false
  def __catch__(conn, kind, reason, wrapped_reason, stack, handle_errors) do
    receive do
      @already_sent ->
        send(self(), @already_sent)
    after
      0 ->
        normalized_reason = Exception.normalize(kind, wrapped_reason, stack)

        conn
        |> Plug.Conn.put_status(status(kind, normalized_reason))
        |> handle_errors.(%{kind: kind, reason: normalized_reason, stack: stack})
    end

    :erlang.raise(kind, reason, stack)
  end

  defp status(:error, error), do: Plug.Exception.status(error)
  defp status(:throw, _throw), do: 500
  defp status(:exit, _exit), do: 500
end
