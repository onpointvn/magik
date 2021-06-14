defmodule ParamTest do
  use ExUnit.Case
  alias Magik.Params

  defmodule Address do
    defstruct [:province, :city]
  end

  test "scrub empty string to nil" do
    params = %{"email" => "", "type" => "customer"}
    assert %{"email" => nil, "type" => "customer"} = Params.scrub_param(params)
  end

  test "scrub string with all space to nil" do
    params = %{"email" => "   ", "type" => "customer"}
    assert %{"email" => nil, "type" => "customer"} = Params.scrub_param(params)
  end

  test "scrub success with atom key" do
    params = %{email: "   ", password: "123"}
    assert %{email: nil, password: "123"} = Params.scrub_param(params)
  end

  test "scrub success with nested map" do
    params = %{
      email: "   ",
      password: "123",
      address: %{street: "", province: "   ", city: "HCM"}
    }

    assert %{address: %{street: nil, province: nil, city: "HCM"}} = Params.scrub_param(params)
  end

  test "scrub array params" do
    params = %{ids: [1, 2, "3", "", "  "]}
    assert %{ids: [1, 2, "3", nil, nil]} = Params.scrub_param(params)
  end

  test "scrub success with mix atom and string key" do
    params = %{email: "   "} |> Map.put("type", "customer")
    assert %{email: nil} = Params.scrub_param(params)
  end

  test "scrub skip struct" do
    params = %{
      "email" => "   ",
      "type" => "customer",
      "address" => %Address{province: "   ", city: "Hochiminh"}
    }

    assert %{"address" => %Address{province: "   ", city: "Hochiminh"}} =
             Params.scrub_param(params)
  end
end
