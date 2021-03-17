defmodule Magik.Paginator do
  @moduledoc """
  Support light paginate the query.
  does not support counting total item because counting on large table is expensive
  update: count total if needed
  """
  import Ecto.Query

  def paginate(query, params, opts \\ []) do
    %{page: page_number, size: page_size} = cast_params(params)
    entries = entries(query, page_number, page_size)
    total? = Map.get(params, "count_total") || Keyword.get(opts, :count_total, false)

    cnt =
      if total? do
        count_entry(query)
      else
        0
      end

    paginator = %{
      page: page_number,
      size: page_size,
      total: cnt,
      total_pages: ceil(cnt / page_size),
      total_entries: cnt,
      has_next?: length(entries) >= page_size,
      has_prev?: page_number > 1
    }

    {entries, paginator}
  end

  defp entries(query, page_number, page_size) do
    offset = page_size * (page_number - 1)

    query
    |> limit(^page_size)
    |> offset(^offset)
    |> HeraCore.Repo.all()
  end

  defp count_entry(query) do
    query
    |> exclude(:order_by)
    |> exclude(:preload)
    |> exclude(:select)
    |> exclude(:distinct)
    |> select(
      [e],
      fragment(
        "count(distinct ?)",
        e.id
      )
    )
    |> HeraCore.Repo.one()
  end

  @default_paging %{
    page: 1,
    size: 10
  }

  @param_schema %{
    page: :integer,
    size: :integer
  }
  defp cast_params(params) do
    {@default_paging, @param_schema}
    |> Ecto.Changeset.cast(params, [:page, :size])
    |> Ecto.Changeset.validate_number(:page, greater_than: 0)
    |> Ecto.Changeset.validate_number(:size, greater_than: 0, less_than_or_equal_to: 80)
    |> Ecto.Changeset.apply_action(:insert)
    |> case do
      {:ok, data} -> data
      _err -> @default_paging
    end
  end
end
