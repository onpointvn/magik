defmodule Magik.GlobalLock.Connection do
  @moduledoc """
  This module connects to the Redis instance.
  """

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, opts},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(uri) when is_binary(uri) do
    Redix.start_link(uri, name: __MODULE__, sync_connect: true)
  end

  def start_link(uri, opts) when is_list(opts) do
    opts = Keyword.merge([name: __MODULE__, sync_connect: true], opts)
    Redix.start_link(uri, opts)
  end
end
