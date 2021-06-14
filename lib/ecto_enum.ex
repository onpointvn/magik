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
        use Magik.EctoEnum, {name1: "Value 1", name2: "value 2"}
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
  """

  defmacro __using__(enum, opts \\ []) do
    type = Keyword.get(opts, :type, :string)

    enum =
      Enum.map(enum, fn
        {k, v} -> {k, v}
        v -> {v, v}
      end)

    enum_values = Enum.map(enum, &elem(&1, 1))

    quote bind_quoted: [enum: enum, enum_values: enum_values, type: type] do
      ### Type definition

      defmodule Type do
        use Ecto.Type
        def type, do: unquote(type)

        defp enum do
          unquote(enum_values)
        end

        def cast(value) when is_binary(value) do
          if value in enum() do
            {:ok, value}
          else
            :error
          end
        end

        def cast(value) when is_atom(value) do
          value
          |> to_string
          |> cast()
        end

        def cast(_), do: :error

        def load(data) when is_binary(data) do
          # if data in enum() do
          {:ok, data}
          # else
          #   :error
          # end
        end

        def load(_), do: :error

        def dump(value) when is_binary(value), do: {:ok, value}
        def dump(value) when is_atom(value), do: {:ok, to_string(value)}
        def dump(_), do: :error
      end

      #### Enum fuctions
      def enum do
        unquote(enum_values)
      end

      for {key, value} <- enum do
        def unquote(:"#{key}")() do
          unquote(value)
        end
      end

      def has_value?(value) do
        value in enum()
      end
    end
  end
end
