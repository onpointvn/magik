defmodule Magik.EctoEnum do
  @moduledoc """
  EctoEnum helps to generate enum type and enum helper function.

  You can define an enum module manually like this

      defmodule MyEnum do
          def enum, do: ["value1", "value2", "value3"]
          def value1, do: "value1"
          def value2, do: "value2"
          def value3, do: "value3"
      end

  Now with EctoEnum you can do it with a few lines of code

      defmodule MyEnum do
          use Magik.EctoEnum, ["value1", "value2", "value3"]
      end


  It still provides same functions with manual implemented module


  ## Use different name and value
  In some case, you want to use a different name instead of the same with value, you can pass a tuple like this

      defmodule MyEnum do
        use Magik.EctoEnum, name1: "Value 1", name2: "value 2"
      end

      MyEnum.name1()
      # => "Value 1"

  ## Use in ecto schema
  EctoEnum also defines a Type module that you can used directly in Ecto schema

      defmodule Order do
        schema "orders do
          field :first_name, :string
          field :last_name, :string
          field :status, MyEnum.Type
        end
      end

  EctoEnum automatically validate value and only allow valid value

  ## Use Enum integer

  You can specify type of column in database, default is `string`

      defmodule MyEnum do
        use Magik.EctoEnum, enum: [name1: 1, name2: 2], type: :integer
      end

  ## use Gettext for enum value with type string

      defmodule MyEnum do
        import MyApp.Gettext
        use Magik.EctoEnum, enum: ["one", "two"], use_gettext: true
      end

  """

  defmacro __using__(opts) do
    support_types = [:string, :integer]

    {enum, type} =
      if Keyword.keyword?(opts) and Keyword.has_key?(opts, :enum) do
        {opts[:enum], opts[:type] || :string}
      else
        {opts, :string}
      end

    use_gettext = opts[:use_gettext]

    if type not in support_types do
      raise "Enum of type #{type} is not support"
    end

    enum =
      case enum do
        {_, _, enum} -> enum
        _ -> enum
      end

    enum =
      Enum.map(enum, fn
        {k, v} -> {k, v}
        v -> {v, v}
      end)

    enum_values = Enum.map(enum, &elem(&1, 1))

    quote bind_quoted: [
            enum: enum,
            enum_values: enum_values,
            type: type,
            use_gettext: use_gettext
          ] do
      ### Type definition

      defmodule Type do
        use Ecto.Type
        def type, do: unquote(type)

        defp enum do
          unquote(enum_values)
        end

        def cast(value) when is_atom(value) do
          value
          |> to_string
          |> cast()
        end

        def cast(value) do
          with {:ok, value} <- Ecto.Type.cast(type(), value),
               true <- value in enum() do
            {:ok, value}
          else
            _ -> :error
          end
        end

        def cast_type(type) do
        end

        def load(data) when is_binary(data) or is_integer(data) do
          {:ok, data}
        end

        def load(_), do: :error

        def dump(value) when is_binary(value) or is_integer(value), do: {:ok, value}
        def dump(value) when is_atom(value), do: {:ok, to_string(value)}
        def dump(_), do: :error
      end

      #### Enum fuctions
      def enum do
        unquote(enum_values)
      end

      if use_gettext and type == :string do
        for {key, value} <- enum do
          def unquote(:"#{key}")() do
            gettext(unquote(value))
            unquote(value)
          end
        end
      else
        for {key, value} <- enum do
          def unquote(:"#{key}")() do
            unquote(value)
          end
        end
      end

      def has_value?(value) do
        value in enum()
      end
    end
  end
end
