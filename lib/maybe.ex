defmodule Magik.Maybe do
  @moduledoc """
  This module provides helpers method to call function depend on condition
  """

  @doc """
  This helper is used in pipe, to invoke function if condition is true, otherwise passing data to nex function

  **Example**

      a = 10
      b = 12

      a
      |> Kernel.*(2)
      |> Maybe.pipe( b != 0, & &1/b)
      |> Kernel.+(10)

  **The condition**
  Could be any value:
  - if condition is `true` then call the function with the first argument
  - if condition is `function/1` then invoke condition function. If return value is `true` then invoke the function with first argument
  - other value of condition don't trigger the function and just return the first argument that passed to this function

  **Example 2**
  Using function condition

      a = 10
      a
      |> Kernel.+(3)
      |> Maybe.pipe(& &1 > 0, & &1 - 5)

  """
  @spec pipe(any, condition :: any, function) :: any
  def pipe(data, true, func) when is_function(func, 1) do
    func.(data)
  end

  def pipe(data, guard_func, func) when is_function(func, 1) and is_function(guard_func, 1) do
    if guard_func.(data) do
      func.(data)
    else
      data
    end
  end

  def pipe(data, _, _), do: data

  @doc """
  This function check first argument, if it is tuple of `{:ok, data}` then invoke the function with `data` of the tuple. Otherwise return the first argument.

  **Example**

      changeset = User.changeset(%User{}, params)
      Repo.insert(changeset)
      |> Maybe.pipe(fn user ->
        # do something with user
      end)

  In case you are using `with`, don't care about this function
  """
  @spec pipe({:ok, any} | any, function) :: any
  def pipe({:ok, data}, func) when is_function(func, 1) do
    func.(data)
  end

  def pipe(data, _), do: data

  @doc """
  This function is mostly used with `with`. In some case, you may want to invoke a function if it meets a specific condition without breaking `with` into 2 block like this

      params = %{}

      with {:ok, data} <- insert_something(),
           :ok <- (if params.checked, do: do_something(data), else: :ok),
           {:ok, another_data} <- send_something(data) do
           # aha
      end

  This function help to write it shorter

      params = %{}
      with {:ok, data} <- insert_something(),
            :ok <- Maybe.run(params.checked, &do_something(data)),
            {:ok, another_data} <- send_something(data) do
            # aha
    end
  """
  def run(nil, _func), do: :ok
  def run(false, _func), do: :ok

  def run(true, func) when is_function(func) do
    func.()
  end

  def ok?({:error, _}), do: false
  def ok?(_), do: true
  def error?({:error, _}), do: true
  def error?(_), do: false
end
