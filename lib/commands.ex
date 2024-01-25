defmodule Magik.Commands do
  @moduledoc """
  Borrow ideas from Ecto.Multi, Commands support build a chain of commands and execute them in order.
  Each operation/command return either {:ok, result} or {:error, error}.
  Execution will stop if any command return {:error, error} and return the error. Otherwise, it will return {:ok, result}.

  It's different from `with` clause, which you cannot use result from success operation in the `else` clause.
  With `Commands` chain, you can use success result so far to handle rollback for example.

  ## Example

    Commands.new()
    |> Commands.chain(:create_user, fn ->
      User.create_user(%{name: "John"})
    end)
    |> Commands.chain(:create_post, fn %{create_user: user} ->
      Post.create_post(%{user_id: user.id, title: "Hello", body: "World"})
    end)
    |> Commands.exec()
    |> case do
      {:ok, %{create_user: user, create_post: post}} ->
        # do something with user and post
      {:error, :create_user, error, _} ->
        {:error, error}
      {:error, :create_post, error, %{create_user: user}} ->
        # delete create_user
    end

  """
  alias Magik.Commands

  defstruct chains: []
  @type t :: %Commands{chains: [{atom() | String.t(), (any() -> any())}]}

  @doc """
  Create a new Commands struct
  """
  @spec new() :: Commands.t()
  def new do
    %Commands{chains: []}
  end

  @doc """
  Add a new command to the chain
  """
  @spec chain(Commands.t(), atom(), (any() -> any())) :: Commands.t()
  def chain(%Commands{} = cmd, key, op) when is_function(op, 0) or is_function(op, 1) do
    %{cmd | chains: [{key, op} | cmd.chains]}
  end

  @doc """
  Add a new command to the chain if condition is true
  """
  @spec chain_if(Commands.t(), atom(), boolean(), (any() -> any())) :: Commands.t()
  def chain_if(%Commands{} = cmd, key, condition, op) do
    if condition do
      chain(cmd, key, op)
    else
      cmd
    end
  end

  @doc """
  Execute the chain
  """
  @spec exec(Commands.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  def exec(%Commands{chains: chains}) do
    chains
    |> Enum.reverse()
    |> Enum.reduce({:ok, %{}}, fn
      {key, op}, {:ok, acc} ->
        result =
          if is_function(op, 0) do
            op.()
          else
            op.(acc)
          end

        case result do
          {:ok, result} -> {:ok, Map.put(acc, key, result)}
          {:error, error} -> {:error, key, error, acc}
        end

      _, error ->
        error
    end)
  end
end
