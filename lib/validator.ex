defmodule Magik.Validator do
  @moduledoc """
  Validation module that support

  - Validate type

  """

  @doc """
  Validate value type that support
  - boolean
  - integer
  - float
  - number
  - string
  - tuple
  - map
  - list
  - atom
  - function
  - keyword
  - struct
  """
  def validate_type(value, :boolean) when is_boolean(value), do: :ok

  def validate_type(value, :integer) when is_integer(value), do: :ok

  def validate_type(value, :float) when is_float(value), do: :ok

  def validate_type(value, :number) when is_number(value), do: :ok

  def validate_type(value, :string) when is_binary(value), do: :ok

  def validate_type(value, :tuple) when is_tuple(value), do: :ok

  def validate_type(value, :map) when is_map(value), do: :ok

  def validate_type(value, :array) when is_list(value), do: :ok

  def validate_type(value, :list) when is_list(value), do: :ok

  def validate_type(value, :atom) when is_atom(value), do: :ok

  def validate_type(value, :function) when is_function(value), do: :ok

  def validate_type([] = _check_item, :keyword), do: :ok

  def validate_type([{atom, _} | _] = _check_item, :keyword) when is_atom(atom), do: :ok

  def validate_type(value, struct_name) when is_struct(value, struct_name), do: :ok

  def validate_type(_, type) when is_tuple(type), do: {:error, "is not an array"}
  def validate_type(_, type), do: {:error, "is not a #{type}"}

  def validate_number(value, checks) when is_list(checks) do
    checks
    |> Enum.map(&validate_number(value, &1))
    |> collect_result()
  end

  @spec validate_number(number, {atom, number}) :: boolean
  def validate_number(number, {:equal_to, check_value}) do
    if number == check_value do
      :ok
    else
      {:error, "must be equal to #{check_value}; got: #{inspect(number)}"}
    end
  end

  def validate_number(number, {:greater_than, check_value}) do
    if number > check_value do
      :ok
    else
      {:error, "must be greater than #{check_value}; got: #{inspect(number)}"}
    end
  end

  def validate_number(number, {:greater_than_or_equal_to, check_value}) do
    if number >= check_value do
      :ok
    else
      {:error, "must be greater than or equal to #{check_value}; got: #{inspect(number)}"}
    end
  end

  def validate_number(number, {:min, check_value}) do
    validate_number(number, {:greater_than_or_equal_to, check_value})
  end

  def validate_number(number, {:less_than, check_value}) do
    if number < check_value do
      :ok
    else
      {:error, "must be less than #{check_value}; got: #{inspect(number)}"}
    end
  end

  def validate_number(number, {:less_than_or_equal_to, check_value}) do
    if number <= check_value do
      :ok
    else
      {:error, "must be less than or equal to #{check_value}; got: #{inspect(number)}"}
    end
  end

  def validate_number(number, {:max, check_value}) do
    validate_number(number, {:less_than_or_equal_to, check_value})
  end

  def validate_number(_number, {check, _check_value}) do
    {:error, "unknown check '#{check}'"}
  end

  @doc """
  Checks whether an item_name conforms the given format.
  ## Examples
  iex> Exop.ValidationChecks.validate_regex(%{a: "bar"}, :a, ~r/bar/)
  :ok
  """
  @spec validate_format(String.t(), Regex.t()) ::
          :ok | {:error, String.t()}
  def validate_format(value, check) when is_binary(value) do
    if Regex.match?(check, value), do: :ok, else: {:error, "format not matched"}
  end

  def validate_format(_value, _check) do
    {:error, "format check only support string"}
  end

  @spec validate_length(map(), atom() | String.t(), map()) :: :ok | {:error, list()}
  def validate_length(value, checks) do
    actual_length = get_length(value)

    checks
    |> Enum.map(fn {condition, condition_value} ->
      validate_length(condition, actual_length, condition_value)
    end)
    |> collect_result()
  end

  @spec get_length(any) :: pos_integer() | {:error, :wrong_type}
  defp get_length(param) when is_list(param), do: length(param)
  defp get_length(param) when is_binary(param), do: String.length(param)
  defp get_length(param) when is_map(param), do: param |> Map.keys() |> get_length()
  defp get_length(param) when is_tuple(param), do: tuple_size(param)
  defp get_length(_param), do: {:error, :wrong_type}

  defp validate_length(_, {:error, :wrong_type}, _check_value) do
    {:error, "length check supports only lists, binaries, maps and tuples"}
  end

  defp validate_length(:min, actual_length, check_value) do
    validate_length(:greater_than_or_equal_to, actual_length, check_value)
  end

  defp validate_length(:greater_than_or_equal_to, actual_length, check_value) do
    (actual_length >= check_value && :ok) ||
      {
        :error,
        "length must be greater than or equal to #{check_value}; got length: #{inspect(actual_length)}"
      }
  end

  defp validate_length(:greater_than, actual_length, check_value) do
    (actual_length > check_value && :ok) ||
      {:error,
       "length must be greater than #{check_value}; got length: #{inspect(actual_length)}"}
  end

  defp validate_length(:max, actual_length, check_value) do
    validate_length(:less_than_or_equal_to, actual_length, check_value)
  end

  defp validate_length(:less_than_or_equal_to, actual_length, check_value) do
    (actual_length <= check_value && :ok) ||
      {
        :error,
        "length must be less than or equal to #{check_value}; got length: #{inspect(actual_length)}"
      }
  end

  defp validate_length(:less_than, actual_length, check_value) do
    (actual_length < check_value && :ok) ||
      {
        :error,
        "length must be less than #{check_value}; got length: #{inspect(actual_length)}"
      }
  end

  defp validate_length(:equal_to, actual_length, check_value) do
    (actual_length == check_value && :ok) ||
      {
        :error,
        "length must be equal to #{check_value}; got length: #{inspect(actual_length)}"
      }
  end

  defp validate_length(:in, actual_length, check_value) do
    if Enum.member?(check_value, actual_length) do
      :ok
    else
      {
        :error,
        "length must be in range #{check_value}; got length: #{inspect(actual_length)}"
      }
    end
  end

  defp validate_length(check, _actual_length, _check_value) do
    {:error, "unknown check '#{check}'"}
  end

  defp collect_result(results) do
    Enum.reduce(results, :ok, fn
      :ok, acc -> acc
      {:error, msg}, :ok -> {:error, [msg]}
      {:error, msg}, {:error, acc_msg} -> {:error, [msg | acc_msg]}
    end)
  end
end
