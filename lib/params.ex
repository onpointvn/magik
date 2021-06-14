defmodule Magik.Params do
  @moduledoc """
  Params provide some helpers method to work with parameters
  """

  @doc """
  A plug which do srubbing params

  **Example**

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
  Convert all parameter which value is empty string or string with all whitespace to nil

  **Example**

    params = %{"keyword" => "   ", "email" => "", "type" => "customer"}
    Magik.Params.scrub_param(params)
    # => %{"keyword" => nil, "email" => nil, "type" => "customer"}
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
end
