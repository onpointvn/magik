defmodule Magik.GlobalLock do
  @moduledoc """
  This module provide mechanism to lock resource using Redis within given TTL

  ## How to use

  1. Add GlobalLock.Connection to `application.ex`

      def start(_type, _args) do
        children = [
          {Opollo.Service.GlobalLock, ["redis://localhost:6379/3]}
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end


  2. Acquire lock and release manually

      with {:ok, mutex} <- GlobalLock.lock("update_order", order.id, 60) do
        MyApp.update_order(order, attrs)
        GlobalLock.unlock(mutex)
      end

  3. Use `with_lock()` to wrap your execution code and it will handle exception

      GlobalLock.with_lock("update_order", order.id, 60, fn ->
        MyApp.update_order(order, attrs)
      end)
  """

  @connection Magik.GlobalLock.Connection
  @prefix "global_lock"

  @unlock_script """
  if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
  else
    return 0
  end
  """

  @doc """
  Lock resource using redis for given ttl in seconds

  ## Example

     lock("order", "SPP1", 60)
  """
  def lock(name_space, id, ttl) when is_integer(ttl) and ttl > 0 do
    key = build_key(name_space, id)
    random = :rand.uniform(999_999_999)

    case Redix.command(@connection, ["SET", key, random, "NX", "EX", ttl]) do
      {:ok, "OK"} ->
        {:ok, {key, random}}

      _err ->
        remaining_time =
          case Redix.command(@connection, ["TTL", key]) do
            {:ok, val} when val > 0 -> val
            _ -> :unknown
          end

        {:error, "Failed to acquired lock on #{inspect({name_space, id})}. Unlocking in #{remaining_time}s"}
    end
  end

  @doc """
  Unlock given mutex resource, with muxte return by `lock/3`

  ## Example

     mutex = lock("order", "SPE", 60)
     # do something with resource
     unlock(mutex)
  """
  def unlock({key, value}) do
    case Redix.command!(@connection, ["EVAL", @unlock_script, 1, key, value]) do
      1 -> :ok
      0 -> {:error, "Failed to unlock resource #{key}. Invalid mutex value"}
    end
  end

  @doc """
  Force release lock and ignore mutex value
  """
  def force_unlock(name_space, id) do
    key = build_key(name_space, id)

    case Redix.command(@connection, ["DEL", key]) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  @doc """
  Try acquire lock, if succeeded, then execute given function.
  This helper function ensure to unlock resource after invoking function successfully or any exception occurs
  """
  def with_lock(name_space, id, ttl, func) do
    with {:ok, mutex} <- lock(name_space, id, ttl) do
      try do
        func.()
      after
        unlock(mutex)
      end
    end
  end

  # build redis key from namespace and id
  defp build_key(name_space, id) do
    if name_space in [nil, ""] or id in [nil, ""] do
      raise("[GlobalLock] in valid namespace or id: #{inspect({name_space, id})}")
    else
      "#{@prefix}:#{name_space}_#{id}"
    end
  end
end
