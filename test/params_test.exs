defmodule ParamTest.StringList do
  @moduledoc false
  def cast(value) when is_binary(value) do
    rs =
      value
      |> String.split(",")
      |> Magik.Params.scrub_param()
      |> Magik.Params.clean_nil()

    {:ok, rs}
  end

  def cast(_), do: :error
end

defmodule ParamTest do
  use ExUnit.Case

  alias Magik.Params
  alias ParamTest.StringList

  defmodule Address do
    @moduledoc false
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
      params = Map.put(%{email: "   "}, "type", "customer")
      assert %{email: nil} = Params.scrub_param(params)
    end

    test "scrub skip struct" do
      params = %{
        "email" => "   ",
        "type" => "customer",
        "address" => %Address{province: "   ", city: "Hochiminh"}
      }

      assert %{"address" => %Address{province: "   ", city: "Hochiminh"}} = Params.scrub_param(params)
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

  describe "Params.cast" do
    @type_checks [
      [:string, "Bluz", "Bluz", :ok],
      [:string, 10, nil, :error],
      [:binary, "Bluz", "Bluz", :ok],
      [:binary, true, nil, :error],
      [:boolean, "1", true, :ok],
      [:boolean, "true", true, :ok],
      [:boolean, "0", false, :ok],
      [:boolean, "false", false, :ok],
      [:boolean, 10, nil, :error],
      [:integer, 10, 10, :ok],
      [:integer, "10", 10, :ok],
      [:integer, 10.0, nil, :error],
      [:integer, "10.0", nil, :error],
      [:float, 10.1, 10.1, :ok],
      [:float, "10.1", 10.1, :ok],
      [:float, 10, 10.0, :ok],
      [:float, "10", 10.0, :ok],
      [:float, "10xx", nil, :error],
      [:map, %{name: "Bluz"}, %{name: "Bluz"}, :ok],
      [:map, %{"name" => "Bluz"}, %{"name" => "Bluz"}, :ok],
      [:map, [], nil, :error],
      [{:array, :integer}, [1, 2, 3], [1, 2, 3], :ok],
      [{:array, :integer}, ["1", "2", "3"], [1, 2, 3], :ok],
      [{:array, :string}, ["1", "2", "3"], ["1", "2", "3"], :ok],
      [StringList, "1,2,3", ["1", "2", "3"], :ok],
      [StringList, "", [], :ok],
      [StringList, [], nil, :error],
      [{:array, StringList}, ["1", "2"], [["1"], ["2"]], :ok],
      [{:array, StringList}, [1, 2], nil, :error],
      [:date, "2020-10-11", ~D[2020-10-11], :ok],
      [:date, "2020-10-11T01:01:01", ~D[2020-10-11], :ok],
      [:date, ~D[2020-10-11], ~D[2020-10-11], :ok],
      [:date, ~N[2020-10-11 01:00:00], ~D[2020-10-11], :ok],
      [:date, "2", nil, :error],
      [:time, "01:01:01", ~T[01:01:01], :ok],
      [:time, ~N[2020-10-11 01:01:01], ~T[01:01:01], :ok],
      [:time, ~T[01:01:01], ~T[01:01:01], :ok],
      [:time, "2", nil, :error],
      [:naive_datetime, "2020-10-11 01:01:01", ~N[2020-10-11 01:01:01], :ok],
      [:naive_datetime, "2020-10-11 01:01:01+07", ~N[2020-10-11 01:01:01], :ok],
      [:naive_datetime, ~N[2020-10-11 01:01:01], ~N[2020-10-11 01:01:01], :ok],
      [:naive_datetime, "2", nil, :error],
      [:datetime, "2020-10-11 01:01:01", ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, "2020-10-11 01:01:01-07", ~U[2020-10-11 08:01:01Z], :ok],
      [:datetime, ~N[2020-10-11 01:01:01], ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, ~U[2020-10-11 01:01:01Z], ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, "2", nil, :error]
    ]

    test "cast base type" do
      Enum.each(@type_checks, fn [type, value, expected_value, expect] ->
        rs = Params.cast(%{"key" => value}, %{key: [type: type]})

        if expect == :ok do
          assert {:ok, %{key: ^expected_value}} = rs
        else
          assert {:error, _} = rs
        end
      end)
    end

    test "cast use default value if field not exist in params" do
      assert {:ok, %{name: "Dzung"}} = Params.cast(%{}, %{name: [type: :string, default: "Dzung"]})
    end

    test "cast use default function if field not exist in params" do
      assert {:ok, %{name: "123"}} = Params.cast(%{}, %{name: [type: :string, default: fn -> "123" end]})
    end

    test "cast validate required skip if default is set" do
      assert {:ok, %{name: "Dzung"}} = Params.cast(%{}, %{name: [type: :string, default: "Dzung", required: true]})
    end

    test "cast func is used if set" do
      assert {:ok, %{name: "Dzung is so handsome"}} =
               Params.cast(%{name: "Dzung"}, %{
                 name: [
                   type: :string,
                   cast_func: fn value -> {:ok, "#{value} is so handsome"} end
                 ]
               })
    end

    @schema %{
      user: [
        type: %{
          name: [type: :string, required: true],
          email: [type: :string, length: [min: 5]],
          age: [type: :integer]
        }
      ]
    }

    test "cast embed type with valid value" do
      data = %{
        user: %{
          name: "D",
          email: "d@h.com",
          age: 10
        }
      }

      assert {:ok, ^data} = Params.cast(data, @schema)
    end

    test "cast with no value should default to nil and skip validation" do
      data = %{
        user: %{
          name: "D",
          age: 10
        }
      }

      assert {:ok, %{user: %{email: nil}}} = Params.cast(data, @schema)
    end

    test "cast embed validation invalid should error" do
      data = %{
        user: %{
          name: "D",
          email: "h",
          age: 10
        }
      }

      assert {:error, %{user: %{email: ["length must be greater than or equal to 5"]}}} = Params.cast(data, @schema)
    end

    test "cast missing required value should error" do
      data = %{
        user: %{
          age: 10
        }
      }

      assert {:error, %{user: %{name: ["is required"]}}} = Params.cast(data, @schema)
    end

    @array_schema %{
      user: [
        type:
          {:array,
           %{
             name: [type: :string, required: true],
             email: [type: :string],
             age: [type: :integer]
           }}
      ]
    }
    test "cass array embed schema with valid data" do
      data = %{
        "user" => [
          %{
            "name" => "D",
            "email" => "d@h.com",
            "age" => 10
          }
        ]
      }

      assert {:ok, %{user: [%{age: 10, email: "d@h.com", name: "D"}]}} = Params.cast(data, @array_schema)
    end

    test "cast empty array embed should ok" do
      data = %{
        "user" => []
      }

      assert {:ok, %{user: []}} = Params.cast(data, @array_schema)
    end

    test "cast nil array embed should ok" do
      data = %{
        "user" => nil
      }

      assert {:ok, %{user: nil}} = Params.cast(data, @array_schema)
    end

    test "cast array embed with invalid value should error" do
      data = %{
        "user" => [
          %{
            "email" => "d@h.com",
            "age" => 10
          },
          %{
            "name" => "HUH",
            "email" => "om",
            "age" => 10
          }
        ]
      }

      assert {:error, %{user: %{name: ["is required"]}}} = Params.cast(data, @array_schema)
    end
  end
end
