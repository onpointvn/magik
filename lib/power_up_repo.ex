defmodule Magik.PowerUpRepo do
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
    end
  end
end
