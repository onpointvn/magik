defmodule ContractTest.User do
  defstruct name: nil, email: nil

  def dumb(_), do: nil
end

defmodule ContractTest do
  use ExUnit.Case

  alias ContractTest.User

  @type_checks [
    [:string, "Bluz", :ok],
    [:string, 10, :error],
    [:integer, 10, :ok],
    [:integer, 10.0, :error],
    [:float, 10.1, :ok],
    [:float, 10, :error],
    [:number, 10.1, :ok],
    [:number, 10, :ok],
    [:number, "123", :error],
    [:tuple, {1, 2}, :ok],
    [:tupple, [1, 2], :error],
    [:map, %{name: "Bluz"}, :ok],
    [:map, %{"name" => "Bluz"}, :ok],
    [:map, [], :error],
    [:array, [1, 2, 3], :ok],
    [:array, 10, :error],
    [:atom, :hihi, :ok],
    [:atom, "string", :error],
    [:function, &User.dumb/0, :ok],
    [:function, "not func", :error],
    [:keyword, [limit: 12], :ok],
    [:keyword, [1, 2], :error],
    [User, %User{email: ""}, :ok],
    [User, %{}, :error],
    [{:array, User}, [%User{email: ""}], :ok],
    [{:array, User}, [], :ok],
    [{:array, User}, %{}, :error]
  ]

  test "validate type" do
    @type_checks
    |> Enum.each(fn [type, value, expect] ->
      rs =
        Magik.Contract.validate(%{"key" => value}, %{
          "key" => [type: type]
        })

      if expect == :ok do
        assert {:ok, _} = rs
      else
        assert {:error, _} = rs
      end
    end)
  end

  test "unexpected key should be removed in the result" do
    assert {:ok, %{"key" => "a string"}} ==
             Magik.Contract.validate(%{"key" => "a string", "strange_key" => "value"}, %{
               "key" => [type: :string, required: true]
             })
  end

  test "validate require" do
    assert {:ok, _} =
             Magik.Contract.validate(%{"key" => "a string"}, %{
               "key" => [type: :string, required: true]
             })
  end

  test "validate require with missing value" do
    assert {:error, %{"key" => ["is required"]}} =
             Magik.Contract.validate(%{}, %{
               "key" => [type: :string, required: true]
             })
  end

  test "validate allow_nil=false with not nil should ok" do
    assert {:ok, _} =
             Magik.Contract.validate(%{"key" => "a string"}, %{
               "key" => [type: :string, allow_nil: false]
             })
  end

  test "validate allow_nil=false with nil should error" do
    assert {:error, %{"key" => ["cannot be nil"]}} =
             Magik.Contract.validate(%{"key" => nil}, %{
               "key" => [type: :string, allow_nil: false]
             })
  end

  test "validate inclusion with valid value should ok" do
    assert {:ok, _} =
             Magik.Contract.validate(%{key: "ok"}, %{
               key: [type: :string, in: ~w(ok error)]
             })
  end

  test "validate inclusion with invalid value should error" do
    assert {:error, %{key: ["not be in the inclusion list"]}} =
             Magik.Contract.validate(%{key: "hello"}, %{
               key: [type: :string, in: ~w(ok error)]
             })
  end

  test "validate exclusion with valid value should ok" do
    assert {:ok, _} =
             Magik.Contract.validate(%{key: "hello"}, %{
               key: [type: :string, not_in: ~w(ok error)]
             })
  end

  test "validate exclusion with invalid value should error" do
    assert {:error, %{key: ["must not be in the exclusion list"]}} =
             Magik.Contract.validate(%{key: "ok"}, %{
               key: [type: :string, not_in: ~w(ok error)]
             })
  end

  test "validate format with match string should ok" do
    assert {:ok, _} =
             Magik.Contract.validate(%{key: "year: 1999"}, %{
               key: [type: :string, format: ~r/year:\s\d{4}/]
             })
  end

  test "validate format with not match string should error" do
    assert {:error, %{key: ["format not matched"]}} =
             Magik.Contract.validate(%{key: ""}, %{
               key: [type: :string, format: ~r/year:\s\d{4}/]
             })
  end

  test "validate format with number should error" do
    assert {:error, %{key: ["format check only support string"]}} =
             Magik.Contract.validate(%{key: 10}, %{
               key: [type: :integer, format: ~r/year:\s\d{4}/]
             })
  end

  @number_tests [
    [:equal_to, 10, 10, :ok],
    [:equal_to, 10, 11, :error],
    [:greater_than_or_equal_to, 10, 10, :ok],
    [:greater_than_or_equal_to, 10, 11, :ok],
    [:greater_than_or_equal_to, 10, 9, :error],
    [:min, 10, 10, :ok],
    [:min, 10, 11, :ok],
    [:min, 10, 9, :error],
    [:greater_than, 10, 11, :ok],
    [:greater_than, 10, 10, :error],
    [:greater_than, 10, 9, :error],
    [:less_than, 10, 9, :ok],
    [:less_than, 10, 10, :error],
    [:less_than, 10, 11, :error],
    [:less_than_or_equal_to, 10, 9, :ok],
    [:less_than_or_equal_to, 10, 10, :ok],
    [:less_than_or_equal_to, 10, 11, :error],
    [:max, 10, 9, :ok],
    [:max, 10, 10, :ok],
    [:max, 10, 11, :error]
  ]
  test "validate number" do
    for [condition, value, actual_value, expect] <- @number_tests do
      rs =
        Magik.Contract.validate(%{key: actual_value}, %{
          key: [type: :integer, number: [{condition, value}]]
        })

      if expect == :ok do
        assert {:ok, %{key: ^actual_value}} = rs
      else
        assert {:error, _} = rs
      end
    end
  end

  test "validate number with string should error" do
    assert {:error, %{key: ["must be a number"]}} =
             Magik.Contract.validate(%{key: "magic"}, %{
               key: [type: :string, number: [min: 10]]
             })
  end

  @length_tests [
    [:equal_to, 10, "1231231234", :ok],
    [:equal_to, 10, "12312312345", :error],
    [:greater_than_or_equal_to, 10, "1231231234", :ok],
    [:greater_than_or_equal_to, 10, "12312312345", :ok],
    [:greater_than_or_equal_to, 10, "123123123", :error],
    [:min, 10, "1231231234", :ok],
    [:min, 10, "12312312345", :ok],
    [:min, 10, "123123123", :error],
    [:greater_than, 10, "12312312345", :ok],
    [:greater_than, 10, "1231231234", :error],
    [:greater_than, 10, "123123123", :error],
    [:less_than, 10, "123123123", :ok],
    [:less_than, 10, "1231231234", :error],
    [:less_than, 10, "12312312345", :error],
    [:less_than_or_equal_to, 10, "123123123", :ok],
    [:less_than_or_equal_to, 10, "1231231234", :ok],
    [:less_than_or_equal_to, 10, "12312312345", :error],
    [:max, 10, "123123123", :ok],
    [:max, 10, "1231231234", :ok],
    [:max, 10, "12312312345", :error]
  ]

  test "validate length" do
    for [condition, value, actual_value, expect] <- @length_tests do
      rs =
        Magik.Contract.validate(%{key: actual_value}, %{
          key: [type: :string, length: [{condition, value}]]
        })

      if expect == :ok do
        assert {:ok, %{key: ^actual_value}} = rs
      else
        assert {:error, _} = rs
      end
    end
  end

  @length_type_tests [
    [:array, 1, [1, 2], :ok],
    [:map, 1, %{a: 1, b: 2}, :ok],
    [:tuple, 1, {1, 2}, :ok]
  ]
  test "validate length with other types" do
    for [type, value, actual_value, expect] <- @length_type_tests do
      rs =
        Magik.Contract.validate(%{key: actual_value}, %{
          key: [type: type, length: [{:greater_than, value}]]
        })

      if expect == :ok do
        assert {:ok, %{key: ^actual_value}} = rs
      else
        assert {:error, _} = rs
      end
    end
  end

  test "validate length for number should error" do
    {:error, %{key: ["length check supports only lists, binaries, maps and tuples"]}} =
      Magik.Contract.validate(%{key: 10}, %{
        key: [type: :number, length: [{:greater_than, 10}]]
      })
  end

  test "validate nested map with success" do
    data = %{name: "Doe John", address: %{city: "HCM", street: "NVL"}}

    schema = %{
      name: [type: :string],
      address: [
        type: %{
          city: [type: :string],
          street: [type: :string]
        }
      ]
    }

    assert {:ok, %{name: "Doe John", address: %{city: "HCM", street: "NVL"}}} =
             Magik.Contract.validate(data, schema)
  end

  test "validate nested map with bad value should error" do
    data = %{name: "Doe John", address: "HCM"}

    schema = %{
      name: [type: :string],
      address: [
        type: %{
          city: [type: :number],
          street: [type: :string]
        }
      ]
    }

    assert {:error, %{address: ["is invalid"]}} = Magik.Contract.validate(data, schema)
  end

  test "validate nested map with bad nested value should error" do
    data = %{name: "Doe John", address: %{city: "HCM", street: "NVL"}}

    schema = %{
      name: [type: :string],
      address: [
        type: %{
          city: [type: :number],
          street: [type: :string]
        }
      ]
    }

    assert {:error, %{address: [%{city: ["is not a number"]}]}} =
             Magik.Contract.validate(data, schema)
  end

  test "validate nested map skip nested check if value nil" do
    data = %{name: "Doe John", address: nil}

    schema = %{
      name: [type: :string],
      address: [
        type: %{
          city: [type: :number],
          street: [type: :string]
        },
        allow_nil: true
      ]
    }

    assert {:ok, _} = Magik.Contract.validate(data, schema)
  end

  test "validate nested map skip nested check if key is missing" do
    data = %{name: "Doe John"}

    schema = %{
      name: [type: :string],
      address: [
        type: %{
          city: [type: :number],
          street: [type: :string]
        },
        allow_nil: true
      ]
    }

    assert {:ok, _} = Magik.Contract.validate(data, schema)
  end

  test "validate array of nested map with valid value should ok" do
    data = %{name: "Doe John", address: [%{city: "HCM", street: "NVL"}]}

    schema = %{
      name: [type: :string],
      address: [
        type:
          {:array,
           %{
             city: [type: :string],
             street: [type: :string]
           }}
      ]
    }

    assert {:ok, _} = Magik.Contract.validate(data, schema)
  end

  test "validate array of nested map with invalid value should error" do
    data = %{name: "Doe John", address: [%{city: "HCM", street: "NVL"}]}

    schema = %{
      name: [type: :string],
      address: [
        type:
          {:array,
           %{
             city: [type: :number],
             street: [type: :string]
           }}
      ]
    }

    assert {:error, %{address: [%{city: ["is not a number"]}]}} =
             Magik.Contract.validate(data, schema)
  end

  def validate_email(_name, value, _params) do
    if Regex.match?(~r/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,4}$/, value) do
      :ok
    else
      {:error, "not a valid email"}
    end
  end

  test "validate with custom function ok with good value" do
    assert {:ok, _} =
             Magik.Contract.validate(
               %{email: "blue@hmail.com"},
               %{email: [type: :string, func: &validate_email/3]}
             )
  end

  test "validate with custom function error with bad value" do
    assert {:error, %{email: ["not a valid email"]}} =
             Magik.Contract.validate(
               %{email: "blue@hmail"},
               %{email: [type: :string, func: &validate_email/3]}
             )
  end
end
