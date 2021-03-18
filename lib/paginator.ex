defmodule Magik.Paginator do
  @moduledoc """
  Support light paginate the query.
  does not support counting total item because counting on large table is expensive
  update: count total if needed
  """
  import Ecto.Query

  @default_config [size: 10, max_size: 100]

  def paginate(query, params, opts \\ []) do
    %{page: page_number, size: page_size} = cast_params(params)
    count_total? = Map.get(params, "count_total") || Keyword.get(opts, :count_total, false)

    repo = get_repo(opts)
    entries = entries(query, page_number, page_size, repo)

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
    page: :integer,
    size: :integer
  }
  defp cast_params(params) do
    {default_paging(), @param_schema}
    |> Ecto.Changeset.cast(params, [:page, :size])
    |> Ecto.Changeset.validate_number(:page, greater_than: 0)
    |> Ecto.Changeset.validate_number(:size, greater_than: 0, less_than_or_equal_to: 80)
    |> Ecto.Changeset.apply_action(:insert)
    |> case do
      {:ok, data} -> data
      _err -> default_paging()
    end
  end

  defp get_config(key, default \\ nil) do
    config = Application.get_env(:magik, :pagination, [])

    @default_config
    |> Keyword.merge(config)
    |> Keyword.get(key, default)
  end

  defp default_paging() do
    %{
      page: 1,
      size: get_config(:size)
    }
  end

  defp get_repo(opts) do
    repo_module = Keyword.get(opts, :repo)
    config_repo = get_config(:repo)

    cond do
      is_atom(repo_module) ->
        repo_module

      is_atom(config_repo) ->
        config_repo

      true ->
        raise ":repo configuration for Paginator is missing"
    end
  end

  defp entries(query, page_number, page_size, repo) do
    offset = page_size * (page_number - 1)

    query
    |> limit(^page_size)
    |> offset(^offset)
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
    |> repo.one()
  end
end
