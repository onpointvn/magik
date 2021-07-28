defmodule Magik.Schema do
  @moduledoc """
  This is only a specification to define a schema to use with `Magik.Params.cast` and `Magik.Contract.validate`

  Schema is just a map or keyword list that follow some simple conventions. Map's key is the field name and the value is a keyword list of field specifications.

  **Example**

  ```elixir
  %{
    name: [type: :string, format: ~r/\d{4}/],
    age: [type: :integer, number: [min: 15, max: 50]].
    skill: [type: {:array, :string}, length: [min: 1, max: 10]]
  }
  ```

  If you only specify type of data, you can write it shorthand style like this

  ```elixir
  %{
    name: :string,
    age: :integer,
    skill: {:array, :string}
  }
  ```


  ## I. Field type

  **Built-in types**

  A type could be any of built-in supported types:

  - `boolean`
  - `string` | `binary`
  - `integer`
  - `float`
  - `number` (integer or float)
  - `date`
  - `time`
  - `datetime` | `utc_datetime`: date time with time zone
  - `naive_datetime`: date time without time zone
  - `map`
  - `keyword`
  - `{array, type}` array of built-in type, all item must be the same type


  **Other types**
  Custom type may be supported depends on module.

  **Nested types**
  Nested types could be a another **schema** or list of **schema**


  ```elixir
  %{
    user: [type: %{
        name: [type: :string]
      }]
  }
  ```

  Or list of schema

  ```elixir
  %{
    users: [type: {:array, %{
        name: [type: :string]
      }} ]
  }
  ```

  ## II. Field casting and default value

  These specifications is used for casting data with `Magik.Params.cast`

  ### 1. Default value

  Is used when the given field is missing or nil.

  - Default could be a value

    ```elixir
    %{
      status: [type: :string, default: "active"]
    }
    ```

  - Or a `function/0`, this function will be invoke each time data is `casted`

    ```elixir
    %{
      published_at: [type: :datetime, default: &DateTime.utc_now/0]
    }
    ```

  ### 2. Custom cast function

  You can provide a function to cast field value instead of using default casting function by using
  `cast_func: <function/1>`

  ```elixir
  %{
      published_at: [type: :datetime, cast_func: &DateTime.from_iso8601/1]
  }
  ```

  ## III. Field validation

  **These validation are supported by `Magik.Validator`**

  ### 1. Type validation

  Type specification above could be used for validating or casting data.

  ### 2. Numeric validation

  Support validating number value. These are list of supported validations:

    - `equal_to`
    - `greater_than_or_equal_to` | `min`
    - `greater_than`
    - `less_than`
    - `less_than_or_equal_to` | `max`

   Define validation: `number: [<name>: <value>, ...]`

  **Example**

  ```elixir
  %{
    age: [type: :integer, number: [min: 1, max: 100]]
  }
  ```

  ### 3. Length validation

  Validate length of supported types include `string`, `array`, `map`, `tuple`, `keyword`.
  Length condions are the same with **Numeric validation**

  Define validation: `length: [<name>: <value>, ...]`

  **Example**

  ```elixir
  %{
    skills: [type: {:array, :string}, length: [min: 0, max: 5]]
  }
  ```


  ### 4. Format validation

  Check if a string match a given pattern.

  Define validation: `format: <Regex>`

  **Example**

  ```elixir
  %{
    year: [type: :string, format: ~r/year:\s\d{4}/]
  }
  ```

  ### 5. Inclusion and exclusion validation

  Check if value is included or not included in given enumerable (`array`, `map`, or `keyword`)

  Define validation: `in: <enumerable>` or `not_in: <enumerable>`

  **Example**

  ```elixir
  %{
    status: [type: :string, in: ["active", "inactive"]],
    selected_option: [type: :integer, not_in: [2,3]]
  }
  ```

  ### 6. Custom validation function

  You can provide a function to validate the value.

  Define validation: `func: <function>`

  Function must be follow this signature

  ```elixir
  @spec func(value::any()) :: :ok | {:error, message::String.t()}
  ```
  """

  @doc """
  Expand short-hand type syntax to full syntax

      field: :string -> field: [type: :string]
      field: {:array, :string} -> field: [type: {:array, :string}]
      field: %{#embedded} -> field: [type: %{#embedded}]
  """
  @spec expand(map()) :: map()
  def expand(schema) do
    schema
    |> Enum.map(&do_expand_field/1)
    |> Enum.into(%{})
  end

  defp do_expand_field({field, type}) when is_atom(type) do
    {field, [type: type]}
  end

  defp do_expand_field({field, type}) when is_map(type) do
    {field, [type: do_expand_type(type)]}
  end

  defp do_expand_field({field, {:array, type}}) do
    {field, [type: {:array, do_expand_type(type)}]}
  end

  defp do_expand_field({field, attrs}) do
    type = attrs[:type]

    if type do
      {field, Keyword.put(attrs, :type, do_expand_type(type))}
    else
      {field, attrs}
    end
  end

  defp do_expand_type(%{} = type) do
    expand(type)
  end

  defp do_expand_type(type), do: type
end
