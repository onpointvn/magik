defmodule Magik.Paginator do
  @moduledoc """
  Support light paginate the query.
  does not support counting total item because counting on large table is expensive
  update: count total if needed
  """
  import Ecto.Query

  def paginate(query, params, opts \\ []) do
    %{page: page_number, size: page_size} = cast_params(Magik.Params.clean_nil(params))
    count_total? = Keyword.get(opts, :count_total, false)

    repo = opts[:repo]

    query_distinct? = Keyword.get(opts, :query_distinct, true)
    entries = entries(query, page_number, page_size, repo, query_distinct?)

    total =
      if count_total? do
        count_entry(query, repo)
      else
        0
      end

    paginator = %{
      page: page_number,
      size: page_size,
      total: total,
      total_pages: ceil(total / page_size),
      total_entries: total,
      has_next?: length(entries) >= page_size,
      has_prev?: page_number > 1
    }

    {entries, paginator}
  end

  @param_schema %{
    page: [type: :integer, number: [min: 1], default: 1],
    size: [type: :integer, number: [min: 1, max: 500], default: 10]
  }
  defp cast_params(params) do
    case Magik.Params.cast(params, @param_schema) do
      {:ok, data} -> data
      _ -> %{page: 1, size: 10}
    end
  end

  defp entries(query, page_number, page_size, repo, query_distinct?) do
    offset = page_size * (page_number - 1)

    query
    |> limit(^page_size)
    |> offset(^offset)
    |> distinct(^query_distinct?)
    |> repo.all()
  end

  defp count_entry(query, repo) do
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
    |> repo.one() || 0
  end
end
