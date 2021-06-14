defmodule ParamTest do
  use ExUnit.Case
  alias Magik.Params

  defmodule Address do
    defstruct [:province, :city]
  end

  describe "test srub_params" do
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

  describe "test clean_nil" do
    test "clean nil map" do
      params = %{"email" => nil, "type" => "customer"}
      assert %{"type" => "customer"} = Params.clean_nil(params)
    end

    test "scrub nil success with list" do
      params = %{ids: [2, nil, 3, nil]}
      assert %{ids: [2, 3]} = Params.clean_nil(params)
    end

    test "clean nil success with nested map" do
      params = %{
        email: nil,
        password: "123",
        address: %{street: nil, province: nil, city: "HCM"}
      }

      assert %{address: %{city: "HCM"}} = Params.clean_nil(params)
    end

    test "clean nil success with nested  list" do
      params = %{
        users: [
          %{
            name: nil,
            age: 20,
            hobbies: ["cooking", nil]
          },
          nil
        ]
      }

      assert %{
               users: [
                 %{
                   age: 20,
                   hobbies: ["cooking"]
                 }
               ]
             } == Params.clean_nil(params)
    end

    test "clean nil skip struct" do
      params = %{
        "email" => "dn@gmail.com",
        "type" => "customer",
        "address" => %Address{province: nil, city: "Hochiminh"}
      }

      assert %{"address" => %Address{province: nil, city: "Hochiminh"}} = Params.clean_nil(params)
    end
  end
end
