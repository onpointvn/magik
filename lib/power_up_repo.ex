defmodule Magik.PowerUpRepo do
  @moduledoc """
  This module provide some helpers functions that common used with Repo

  ## How to use

  `use Magik.PowerUpRepo` in your Repo module and all helper functions are ready for use

      defmodule MyApp.Repo do
        use Ecto.Repo,
            otp_app: :my_app,
            adapter: Ecto.Adapters.Postgres

        use Magik.PowerUpRepo
      end

  """

  defmacro __using__(_) do
    quote do
      def paginate(query, paging_params, opts \\ []) do
        Magik.Paginator.paginate(query, paging_params, [{:repo, __MODULE__} | opts])
      end

      def preload_paginate({entries, paginate}, preloads) do
        {__MODULE__.preload(entries, preloads), paginate}
      end

      def preload_stream(stream, size \\ 50, preloads) do
        stream
        |> Stream.chunk_every(size)
        |> Stream.flat_map(fn chunk ->
          __MODULE__.preload(chunk, preloads)
        end)
      end

      def stream_query(query, opts \\ [page_size: 50]) do
        Stream.resource(
          fn -> %{size: opts[:page_size], has_next?: true, page: 0} end,
          fn opts ->
            case opts do
              %{has_next?: false} ->
                {:halt, nil}

              %{size: _size, page: page} ->
                # tupple of {entries, paginate}
                Magik.Paginator.paginate(query, %{opts | page: page + 1}, repo: __MODULE__)
            end
          end,
          fn _ -> nil end
        )
      end

      def find(query_or_module, filters) do
        found =
          query_or_module
          |> Querie.Filter.apply(filters)
          |> limit(1)
          |> __MODULE__.one()

        if is_nil(found) do
          {:error, :not_found}
        else
          {:ok, found}
        end
      end
    end
  end

  @doc """
  Fetch query by pagination parama

  **Example**

      query = from(p in Product, where: p.quantity > 10)
      {entries, paginator} = Repo.paginate(query, %{page: 2, size: 5})
  """
  @callback paginate(query :: Ecto.Queryable.t(), paging_params :: map(), opts :: keyword()) ::
              {list(), map()}

  @doc """
  Preload entries return from `Repo.paginate`

  **Example**

      {entries, paginator} =
        from(p in Product, where: p.quantity > 10 )
        |> Repo.paginate(%{page: 2, size: 5})
        |> Repo.preload([:brand, :category])
  """
  @callback preload_paginate({entries :: list(), paginator :: map()}, preloads :: keyword()) ::
              {list(), map()}

  @doc """
  Load query with given size and provide the result as a stream

  **Options**
  - page_size: number of entry to load per batch


  **Example**
      from(p in Product, where: p.quantity > 10 )
      |> Repo.stream_query(20)
      |> Stream.map( & &1.name)
      |> Enum.to_list

  """
  @callback stream_query(queryable :: Ecto.Queryable.t(), opts :: keyword()) ::
              Enumerable.t()

  @doc """
  Find the first entry in the database that match the filter

      case Repo.find(Product, brand_id: 1, is_active: true) do
        {:ok, product} ->
            IO.puts(product.name)
        {:error, :not_found} ->
            IO.puts("No product found")
      end

  """
  @callback find(queryable :: Ecto.Queryable.t(), keyword() | map()) ::
              {:ok, item :: any()} | {:error, :not_found}
end
