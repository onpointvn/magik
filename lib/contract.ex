defmodule Magik.Contract do
  @moduledoc """

  validate contract schema

  ## Support validation

  **Type**

  Support built-in types;
  - `boolean`
  - `integer`,
  - `float`
  - `number` - string or integer
  - `string`
  - `tuple`
  - `map`
  - `array`
  - `list`
  - `atom`
  - `function`
  - `keyword`
  - `struct`
  - `array` of type

  Example:

  ```elixir
  Magik.Contract.validate(%{name: "Bluz"}, %{name: [type: :string]})
  Magik.Contract.validate(%{id: 123}, %{name: [type: :integer]})
  Magik.Contract.validate(%{id: 123}, %{name: [type: {:array, :integer}]})
  Magik.Contract.validate(%{user: %User{}}, %{user: [type: User]})
  Magik.Contract.validate(%{user: %User{}}, %{user: [type: {:array: User}]})
  ```

  **Required**

  ```elixir
  Magik.Contract.validate(%{name: "Bluz"}, %{name: [type: :string, required: true]})
  ```

  **Allow nil**

  ```elixir
  Magik.Contract.validate(
                        %{name: "Bluz", email: nil},
                        %{
                          name: [type: :string],
                          email: [type: string, allow_nil: false]
                         })
  ```


  **Inclusion/Exclusion**

  ```elixir
  Magik.Contract.validate(
                  %{status: "active"},
                  %{status: [type: :string, in: ~w(active in_active)]}
                 )

  Magik.Contract.validate(
                  %{status: "active"},
                  %{status: [type: :string, not_in: ~w(banned locked)]}
                 )
  ```

  **Format**

  Validate string against regex pattern

  ```elixir
  Magik.Contract.validate(
                %{email: "Bluzblu@gm.com"},
                %{name: [type: :string, format: ~r/.+?@.+\.com/]
                })
  ```

  **Number**

  Validate number value

  ```elixir
  Magik.Contract.validate(
                %{age: 200},
                %{age: [type: :integer, number[greater_than: 0, less_than: 100]]
                })
  ```

  Support conditions
  - `equal_to`
  - `greater_than_or_equal_to` | `min`
  - `greater_than`
  - `less_than`
  - `less_than_or_equal_to` | `max`



  **Length**

  Check length of `list`, `map`, `string`, `keyword`, `tuple`
  Supported condtions are the same with **Number** check

  ```elixir
  Magik.Contract.validate(
                %{title: "Hello world"},
                %{age: [type: :string, length: [min: 10, max: 100]]
                })
  ```


  **Custom validation function**

  Invoke given function to validate value.
  The function signature must be

  ```
  func(field_name ::(String.t() | atom()), value :: any(), all_params :: map()) :: :ok | {:error, message}
  ```

  ```elixir
  Magik.Contract.validate(
                %{email: "blue@hmail.com"},
                %{email: [type: :string, func: &validate_email/3]})

  def validate_email(_name, email, _params) do
    if Regex.match?(~r/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,4}$/, email) do
      :ok
    else
      {:error, "not a valid email"}
    end
  end
  ```

  **Nested map**

  Nested map declaration is the same.

  ```elixir
  data =   %{name: "Doe John", address: %{city: "HCM", street: "NVL"} }
  schema = %{
      name: [type: :string],
      address: [type: %{
              city: [type: :string],
              street: [type: :string]
            }]
    }
  Magik.Contract.validate(data, schema)
  ```

  **Nested list**

  ```elixir
  data =   %{name: "Doe John", address: [%{city: "HCM", street: "NVL"}] }
  address = %{ city: [type: :string],  street: [type: :string] }
  schema = %{
      name: [type: :string],
      address: [type: {:array, address}]
     }
  Magik.Contract.validate(data, schema)
  ```
  """

  alias Magik.Validator

  def validate(data, schema) do
    validation_result =
      schema
      |> Enum.map(fn {field_name, validations} ->
        validations =
          if Keyword.has_key?(validations, :allow_nil) do
            validations
          else
            [{:allow_nil, false} | validations]
          end

        validations
        |> Enum.map(fn validation ->
          value = Map.get(data, field_name, :__missing)
          do_validate(value, validation, field_name: field_name, data: data)
        end)
        |> collect_result()
        |> case do
          :ok -> :ok
          {_, errors} -> {:error, {field_name, errors}}
        end
      end)
      |> collect_result()

    case validation_result do
      :ok -> {:ok, data}
      {:error, errors} -> {:error, Map.new(errors)}
    end
  end

  defp do_validate(:__missing, {:required, true}, _opts) do
    {:error, "is required"}
  end

  defp do_validate(_, {:required, _}, _), do: :ok

  defp do_validate(:__missing, _, _), do: :ok

  defp do_validate(value, {:allow_nil, allow_nil}, _) when is_boolean(allow_nil) do
    if not is_nil(value) or allow_nil do
      :ok
    else
      {:error, "cannot be nil"}
    end
  end

  defp do_validate(nil, _, _), do: :ok

  # validate nested type
  defp do_validate(%{} = value, {:type, type}, _) when is_map(type) do
    case validate(value, type) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp do_validate(_value, {:type, type}, _) when is_map(type) do
    {:error, "is not a nested map"}
  end

  defp do_validate(value, {:type, {:array, type}}, _) when is_list(value) do
    results =
      value
      |> Enum.map(fn item ->
        do_validate(item, {:type, type}, value)
      end)

    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      Enum.find(results, fn {rs, _} -> rs == :error end)
    end
  end

  defp do_validate(value, {:type, type}, _) do
    Validator.validate_type(value, type)
  end

  defp do_validate(value, {:in, enum}, _) do
    if Enum.member?(enum, value) do
      :ok
    else
      {:error, "not be in the inclusion list"}
    end
  end

  defp do_validate(value, {:not_in, enum}, _) do
    if Enum.member?(enum, value) do
      {:error, "must not be in the exclusion list"}
    else
      :ok
    end
  end

  defp do_validate(value, {:format, format}, _) do
    Validator.validate_format(value, format)
  end

  defp do_validate(value, {:number, checks}, _) when is_number(value) do
    Validator.validate_number(value, checks)
  end

  defp do_validate(_value, {:number, _checks}, _) do
    {:error, "is not a number"}
  end

  defp do_validate(value, {:length, checks}, _) do
    Validator.validate_length(value, checks)
  end

  defp do_validate(value, {:func, func}, opts) when is_function(func, 3) do
    func.(opts[:field_name], value, opts[:data])
  end

  defp collect_result(results) do
    summary =
      Enum.reduce(results, :ok, fn
        :ok, acc -> acc
        {:error, msg}, :ok -> {:error, [msg]}
        {:error, msg}, {:error, acc_msg} -> {:error, [msg | acc_msg]}
      end)

    case summary do
      :ok ->
        :ok

      {:error, errors} ->
        errors =
          errors
          |> Enum.map(fn item ->
            if is_list(item) do
              item
            else
              [item]
            end
          end)
          |> Enum.concat()

        {:error, errors}
    end
  end
end
