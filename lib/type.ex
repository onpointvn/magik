defmodule Magik.Type do
  @moduledoc """
  Cast data to target type.
  Much code of this module is borrowed from `Ecto.Type`
  """

  @base ~w(
    integer float decimal boolean string map binary id binary_id any
    datetime utc_datetime naive_datetime date time
  )a

  def cast({:embed, mod, params}, value), do: mod.cast(value, params)

  def cast(type, value) do
    cast_fun(type).(value)
  end

  def cast!(type, value) do
    case cast(type, value) do
      {:ok, data} ->
        data

      _ ->
        raise "invalid #{inspect(type)}"
    end
  end

  def is_base_type(type) do
    type in @base
  end

  defp cast_fun(:boolean), do: &cast_boolean/1
  defp cast_fun(:integer), do: &cast_integer/1
  defp cast_fun(:float), do: &cast_float/1
  defp cast_fun(:string), do: &cast_binary/1
  defp cast_fun(:binary), do: &cast_binary/1
  defp cast_fun(:any), do: &{:ok, &1}
  defp cast_fun(:date), do: &cast_date/1
  defp cast_fun(:time), do: &maybe_truncate_usec(cast_time(&1))
  defp cast_fun(:datetime), do: &maybe_truncate_usec(cast_utc_datetime(&1))
  defp cast_fun(:naive_datetime), do: &maybe_truncate_usec(cast_naive_datetime(&1))
  defp cast_fun(:utc_datetime), do: &maybe_truncate_usec(cast_utc_datetime(&1))
  defp cast_fun(:map), do: &cast_map/1

  defp cast_fun(mod) when is_atom(mod), do: &maybe_cast_custom_type(mod, &1)

  defp cast_fun({:array, {:embed, _, _} = type}) do
    fun = fn value -> cast(type, value) end
    &array(&1, fun, true, [])
  end

  defp cast_fun({:array, type}) do
    fun = cast_fun(type)
    &array(&1, fun, true, [])
  end

  defp cast_fun({:map, {:embed, _, _} = type}) do
    fun = cast_fun(type)
    &map(&1, fun, false, %{})
  end

  defp cast_fun({:map, type}) do
    fun = cast_fun(type)
    &map(&1, fun, true, %{})
  end

  defp cast_fun(mod) when is_atom(mod) do
    fn
      nil -> {:ok, nil}
      value -> mod.cast(value)
    end
  end

  defp cast_boolean(term) when term in ~w(true 1), do: {:ok, true}
  defp cast_boolean(term) when term in ~w(false 0), do: {:ok, false}
  defp cast_boolean(term) when is_boolean(term), do: {:ok, term}
  defp cast_boolean(_), do: :error

  defp cast_integer(term) when is_binary(term) do
    case Integer.parse(term) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  defp cast_integer(term) when is_integer(term), do: {:ok, term}
  defp cast_integer(_), do: :error

  defp cast_float(term) when is_binary(term) do
    case Float.parse(term) do
      {float, ""} -> {:ok, float}
      _ -> :error
    end
  end

  defp cast_float(term) when is_float(term), do: {:ok, term}
  defp cast_float(term) when is_integer(term), do: {:ok, :erlang.float(term)}
  defp cast_float(_), do: :error

  defp cast_binary(term) when is_binary(term), do: {:ok, term}
  defp cast_binary(_), do: :error

  ## Date

  defp cast_date(binary) when is_binary(binary) do
    case Date.from_iso8601(binary) do
      {:ok, _} = ok ->
        ok

      {:error, _} ->
        case NaiveDateTime.from_iso8601(binary) do
          {:ok, naive_datetime} -> {:ok, NaiveDateTime.to_date(naive_datetime)}
          {:error, _} -> :error
        end
    end
  end

  defp cast_date(%Date{} = date), do: {:ok, date}
  defp cast_date(%DateTime{} = date), do: {:ok, DateTime.to_date(date)}
  defp cast_date(%NaiveDateTime{} = date), do: {:ok, NaiveDateTime.to_date(date)}
  defp cast_date(_), do: :error

  ## Time
  defp cast_time(binary) when is_binary(binary) do
    case Time.from_iso8601(binary) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end

  defp cast_time(%Time{} = time), do: {:ok, time}
  defp cast_time(%DateTime{} = date), do: {:ok, DateTime.to_time(date)}
  defp cast_time(%NaiveDateTime{} = date), do: {:ok, NaiveDateTime.to_time(date)}
  defp cast_time(_), do: :error

  ## Naive datetime

  defp cast_naive_datetime("-" <> rest) do
    with {:ok, datetime} <- cast_naive_datetime(rest) do
      {:ok, %{datetime | year: datetime.year * -1}}
    end
  end

  defp cast_naive_datetime(binary) when is_binary(binary) do
    case NaiveDateTime.from_iso8601(binary) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end

  defp cast_naive_datetime(%{year: empty, month: empty, day: empty, hour: empty, minute: empty}) when empty in ["", nil],
    do: {:ok, nil}

  defp cast_naive_datetime(%{} = map) do
    with {:ok, %Date{} = date} <- cast_date(map),
         {:ok, %Time{} = time} <- cast_time(map) do
      NaiveDateTime.new(date, time)
    else
      _ -> :error
    end
  end

  defp cast_naive_datetime(_) do
    :error
  end

  ## UTC datetime
  defp cast_utc_datetime("-" <> rest) do
    with {:ok, utc_datetime} <- cast_utc_datetime(rest) do
      {:ok, %{utc_datetime | year: utc_datetime.year * -1}}
    end
  end

  defp cast_utc_datetime(binary) when is_binary(binary) do
    case DateTime.from_iso8601(binary) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(binary) do
          {:ok, naive_datetime} -> {:ok, DateTime.from_naive!(naive_datetime, "Etc/UTC")}
          {:error, _} -> :error
        end

      {:error, _} ->
        :error
    end
  end

  defp cast_utc_datetime(%DateTime{time_zone: "Etc/UTC"} = datetime), do: {:ok, datetime}

  defp cast_utc_datetime(%DateTime{} = datetime) do
    case datetime |> DateTime.to_unix(:microsecond) |> DateTime.from_unix(:microsecond) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end

  defp cast_utc_datetime(value) do
    case cast_naive_datetime(value) do
      {:ok, %NaiveDateTime{} = naive_datetime} ->
        {:ok, DateTime.from_naive!(naive_datetime, "Etc/UTC")}

      {:ok, _} = ok ->
        ok

      :error ->
        :error
    end
  end

  defp cast_map(term) when is_map(term), do: {:ok, term}
  defp cast_map(_), do: :error

  defp maybe_cast_custom_type(mod, value) do
    mod.cast(value)
  end

  defp array([nil | t], fun, true, acc) do
    array(t, fun, true, [nil | acc])
  end

  defp array([h | t], fun, skip_nil?, acc) do
    case fun.(h) do
      {:ok, h} -> array(t, fun, skip_nil?, [h | acc])
      :error -> :error
      {:error, _custom_errors} -> :error
    end
  end

  defp array([], _fun, _skip_nil?, acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp array(_, _, _, _) do
    :error
  end

  defp map(map, fun, skip_nil?, acc) when is_map(map) do
    map_each(Map.to_list(map), fun, skip_nil?, acc)
  end

  defp map(_, _, _, _) do
    :error
  end

  defp map_each([{key, nil} | t], fun, true, acc) do
    map_each(t, fun, true, Map.put(acc, key, nil))
  end

  defp map_each([{key, value} | t], fun, skip_nil?, acc) do
    case fun.(value) do
      {:ok, value} -> map_each(t, fun, skip_nil?, Map.put(acc, key, value))
      :error -> :error
      {:error, _custom_errors} -> :error
    end
  end

  defp map_each([], _fun, _skip_nil?, acc) do
    {:ok, acc}
  end

  defp maybe_truncate_usec({:ok, struct}), do: {:ok, truncate_usec(struct)}
  defp maybe_truncate_usec(:error), do: :error

  defp truncate_usec(nil), do: nil
  defp truncate_usec(%{microsecond: {0, 0}} = struct), do: struct
  defp truncate_usec(struct), do: %{struct | microsecond: {0, 0}}
end
