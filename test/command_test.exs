defmodule CommandTest do
  use ExUnit.Case
  alias Magik.Commands

  test "init command" do
    assert %Commands{chains: []} = Commands.new()
  end

  test "add command" do
    assert %Commands{chains: [{:step1, func}]} =
             Commands.new() |> Commands.chain(:step1, fn -> {:ok, "one"} end)

    assert is_function(func, 0)
  end

  test "add command accept 1 argument" do
    assert %Commands{chains: [{:step1, func}]} =
             Commands.new() |> Commands.chain(:step1, fn acc -> {:ok, acc} end)

    assert is_function(func, 1)
  end

  test "add command if condition is true" do
    assert %Commands{chains: [{:step1, func}]} =
             Commands.new() |> Commands.chain_if(:step1, true, fn -> {:ok, "one"} end)

    assert is_function(func, 0)
  end

  test "do not add command if condition is false" do
    assert %Commands{chains: []} =
             Commands.new() |> Commands.chain_if(:step1, false, fn -> {:ok, "one"} end)
  end

  test "return accumulate result if all success" do
    assert {:ok, %{step1: "one", step2: "two"}} =
             Commands.new()
             |> Commands.chain(:step1, fn -> {:ok, "one"} end)
             |> Commands.chain(:step2, fn -> {:ok, "two"} end)
             |> Commands.exec()
  end

  test "return error and accumulate if one fail" do
    assert {:error, :step2, "two", %{step1: "one"}} =
             Commands.new()
             |> Commands.chain(:step1, fn -> {:ok, "one"} end)
             |> Commands.chain(:step2, fn -> {:error, "two"} end)
             |> Commands.exec()
  end
end
