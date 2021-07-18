defmodule MagikEctoEnumTest.OrderStatus do
  use Magik.EctoEnum, ["new", "pending", "processing", "completed", "cancelled"]
end

defmodule MagikEctoEnumTest.ContractType do
  use Magik.EctoEnum, part_time: "Part time", full_time: "Full time", cooperator: "Cooperator"
end

defmodule MagikEctoEnumTest.IntegerStatus do
  use Magik.EctoEnum, enum: [good: 1, bad: 2, unknown: 3], type: :integer
end

defmodule MagikEctoEnumTest do
  use ExUnit.Case
  alias MagikEctoEnumTest.OrderStatus
  alias MagikEctoEnumTest.ContractType
  alias MagikEctoEnumTest.IntegerStatus

  @states ["new", "pending", "processing", "completed", "cancelled"]
  test "enum value should match" do
    assert OrderStatus.enum() -- @states == []
  end

  test "value helper function should pass" do
    @states
    |> Enum.each(fn state ->
      assert apply(OrderStatus, :"#{state}", []) == state
    end)
  end

  test "enum with tuple key - value" do
    assert "Part time" == ContractType.part_time()
    assert "Full time" == ContractType.full_time()
  end

  test "enum values with tuple key - value" do
    assert ["Part time", "Full time", "Cooperator"] == ContractType.enum()
  end

  test "enum has_value? with tuple key - value" do
    assert true == ContractType.has_value?("Part time")
    assert false == ContractType.has_value?("part time")
  end

  test "check has_value should pass all" do
    @states
    |> Enum.each(fn state ->
      assert OrderStatus.has_value?(state)
    end)
  end

  test "cast value in enum should pass" do
    assert OrderStatus.Type.cast("new") == {:ok, "new"}
    assert OrderStatus.Type.cast(:pending) == {:ok, "pending"}
  end

  test "cast value not in enum should failed" do
    assert OrderStatus.Type.cast("1") == :error
    assert OrderStatus.Type.cast(10) == :error
    assert OrderStatus.Type.cast(:ok) == :error
  end

  test "cast integer for integer enum should pass" do
    assert IntegerStatus.Type.cast("1") == {:ok, 1}
    assert IntegerStatus.Type.cast(1) == {:ok, 1}
  end

  test "cast other value fo integer enum should error" do
    assert IntegerStatus.Type.cast("hi") == :error
    assert IntegerStatus.Type.cast(10.0) == :error
  end

  test "load data in enum should pass" do
    @states
    |> Enum.each(fn state ->
      assert OrderStatus.Type.load(state) == {:ok, state}
    end)
  end

  test "load string not in enum should pass" do
    assert OrderStatus.Type.load("hihi") == {:ok, "hihi"}
  end

  test "dump string value should pass" do
    @states
    |> Enum.each(fn state ->
      assert OrderStatus.Type.dump(state) == {:ok, state}
    end)
  end
end
