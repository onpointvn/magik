defmodule MagikTest do
  use ExUnit.Case
  doctest Magik

  test "greets the world" do
    assert Magik.hello() == :world
  end
end
