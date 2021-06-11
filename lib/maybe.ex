defmodule Magik.Maybe do
  def pipe(data, false, _), do: data
  def pipe(data, nil, _), do: data

  def pipe(data, true, func) when is_function(func, 1) do
    func.(data)
  end

  def pipe_ok({:ok, data}, func) when is_function(func, 1) do
    func.(data)
  end

  def pipe_ok(data, _), do: data

  def maybe(false, _func), do: :ok

  def maybe(true, func) when is_function(func) do
    func.()
  end

  def ok?({:error, _}), do: false
  def ok?(_), do: true
  def error?({:error, _}), do: true
  def error?(_), do: false
end
