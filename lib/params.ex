defmodule Magik.Params do
  @moduledoc """
  Params provide some helpers method to work with parameters
  """

  @doc """
  A plug which do srubbing params

  **Use in Router**

      defmodule MyApp.Router do
        ...
        plug Magik.Params.plug_srub
        ...
      end

  **Use in controller**

      plug Magik.Params.plug_srub when action in [:index, :show]
      # or specify which field to scrub
      plug Magik.Params.plug_srub, ["id", "keyword"] when action in [:index, :show]

  """
  def plug_srub(conn, keys \\ []) do
    params =
      if keys == [] do
        scrub_param(conn.params)
      else
        Enum.reduce(keys, conn.params, fn key, params ->
          case Map.fetch(conn.params, key) do
            {:ok, value} -> Map.put(params, key, scrub_param(value))
            :error -> params
          end
        end)
      end

    %{conn | params: params}
  end

  @doc """
  Convert all parameter which value is empty string or string with all whitespace to nil. It works with nested map and list too.

  **Example**

      params = %{"keyword" => "   ", "email" => "", "type" => "customer"}
      Magik.Params.scrub_param(params)
      # => %{"keyword" => nil, "email" => nil, "type" => "customer"}

      params = %{user_ids: [1, 2, "", "  "]}
      Magik.Params.scrub_param(params)
      # => %{user_ids: [1, 2, nil, nil]}
  """
  def scrub_param(%{__struct__: mod} = struct) when is_atom(mod) do
    struct
  end

  def scrub_param(%{} = param) do
    Enum.reduce(param, %{}, fn {k, v}, acc ->
      Map.put(acc, k, scrub_param(v))
    end)
  end

  def scrub_param(param) when is_list(param) do
    Enum.map(param, &scrub_param/1)
  end

  def scrub_param(param) do
    if scrub?(param), do: nil, else: param
  end

  defp scrub?(" " <> rest), do: scrub?(rest)
  defp scrub?(""), do: true
  defp scrub?(_), do: false

  @doc """
  Clean all nil field from params, support nested map and list.

  **Example**

      params = %{"keyword" => nil, "email" => nil, "type" => "customer"}
      Magik.Params.clean_nil(params)
      # => %{"type" => "customer"}

      params = %{user_ids: [1, 2, nil]}
      Magik.Params.clean_nil(params)
      # => %{user_ids: [1, 2]}
  """
  @spec clean_nil(any) :: any
  def clean_nil(%{__struct__: mod} = param) when is_atom(mod) do
    param
  end

  def clean_nil(%{} = param) do
    Enum.reduce(param, %{}, fn {k, v}, acc ->
      if is_nil(v) do
        acc
      else
        Map.put(acc, k, clean_nil(v))
      end
    end)
  end

  def clean_nil(param) when is_list(param) do
    Enum.reduce(param, [], fn item, acc ->
      if is_nil(item) do
        acc
      else
        [clean_nil(item) | acc]
      end
    end)
    |> Enum.reverse()
  end

  def clean_nil(param), do: param

  alias Magik.Validator
  alias Magik.Type

  @doc """
  Cast and validate params with given schema
  """

  @spec cast(data :: map(), schema :: map()) :: {:ok, map()} | {:error, errors :: map()}
  def cast(data, schema) do
    {status, results} =
      schema
      |> Enum.map(fn {field_name, validations} ->
        {type, validations} = Keyword.pop(validations, :type)
        {default, validations} = Keyword.pop(validations, :default)

        value =
          case Map.fetch(data, field_name) do
            {:ok, value} -> value
            _ -> Map.get(data, "#{field_name}", :__missing)
          end

        case cast_value(value, type, default) do
          :error ->
            {:error, {field_name, ["is in valid"]}}

          {:error, errors} ->
            {:error, {field_name, errors}}

          {:ok, data} ->
            validations
            |> Enum.map(fn validation ->
              do_validate(value, validation, field_name: field_name, data: data)
            end)
            |> collect_validation_result()
            |> case do
              :ok -> {:ok, {field_name, data}}
              {_, errors} -> {:error, {field_name, errors}}
            end
        end
      end)
      |> collect_schema_result()

    {status, Map.new(results)}
  end

  defp cast_value(:__missing, _type, default), do: {:ok, default}

  # cast array of custom map
  defp cast_value(value, {:array, %{} = type}, _) do
    Type.cast({:array, {:embed, __MODULE__, type}}, value)
  end

  # cast nested map
  defp cast_value(value, %{} = type, _) do
    Type.cast({:embed, __MODULE__, type}, value)
  end

  defp cast_value(value, type, _) do
    Type.cast(type, value)
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

  defp collect_schema_result(results) do
    Enum.reduce(results, {:ok, []}, fn
      {:ok, data}, {:ok, acc} -> {:ok, [data | acc]}
      {:error, error}, {:ok, _} -> {:error, [error]}
      {:error, error}, {:error, acc} -> {:error, [error | acc]}
      _, acc -> acc
    end)
  end
end
