defmodule Magik.Contract do
  @moduledoc """

  `Contract` helps to define a contract for function call, and do validate contract data with:

  - Validate type
  - Validate required
  - Validate `in`|`not_in` enum
  - Valiate length for `string`, `enumerable`
  - Validate number
  - Validate string against regex pattern
  - Custom validation function
  - With support nested type
  - Clean not allowed fields

  ```elixir

  @update_user_contract %{
    user: [type: User, required: true],
    attributes: [type: %{
      email: [type: :string],
      status: [type: :string, in: ~w(active in_active)]
      age: [type: :integer, number: [min: 10, max: 80]],
    }, required: true]
  }

  def update_user(contract) do
    with {:ok, validated_data} do
       validated_data.user
       |> Ecto.Changeset.change(validated_data.attributes)
       |> Repo.update
    else
      {:error, errors} -> IO.inspect(errors)
    end
  end

  ```

  **NOTES: Contract only validate data, not cast data**

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

  @doc """
  Validate data against given schema
  """

  @spec validate(data :: map(), schema :: map()) :: {:ok, map()} | {:error, errors :: map()}
  def validate(data, schema) do
    {status, results} =
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
        |> collect_validation_result()
        |> case do
          {:ok, data} -> {:ok, {field_name, data}}
          {_, errors} -> {:error, {field_name, errors}}
        end
      end)
      |> collect_schema_result()

    {status, Map.new(results)}
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
    validate(value, type)
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

    error =
      Enum.find(results, fn
        {rs, _} -> rs == :error
      end)

    if not is_nil(error) do
      error
    else
      {:ok, Enum.map(results, fn {_, data} -> data end)}
    end
  end

  defp do_validate(value, {:type, type}, _) do
    case Validator.validate_type(value, type) do
      :ok -> {:ok, value}
      err -> err
    end
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

  defp collect_validation_result(results) do
    summary =
      Enum.reduce(results, {:ok, nil}, fn
        :ok, acc -> acc
        {:ok, data}, {:ok, _acc} -> {:ok, data}
        {:error, msg}, {:ok, _} -> {:error, [msg]}
        {:error, msg}, {:error, acc_msg} -> {:error, [msg | acc_msg]}
        _, acc -> acc
      end)

    case summary do
      {:ok, _} ->
        summary

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

  defp collect_schema_result(results) do
    Enum.reduce(results, {:ok, []}, fn
      {:ok, data}, {:ok, acc} -> {:ok, [data | acc]}
      {:error, error}, {:ok, _} -> {:error, [error]}
      {:error, error}, {:error, acc} -> {:error, [error | acc]}
      _, acc -> acc
    end)
  end
end
