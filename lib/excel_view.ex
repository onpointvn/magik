defmodule Magik.ExcelView do
  defmacro __using__(_) do
    quote do
      @before_compile Magik.ExcelView
      def render_row(struct, fields) do
        Magik.ExcelView.render_row(struct, __MODULE__, fields: fields)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def render_cell(field, struct), do: Map.get(struct, :field)
    end
  end

  def render_row(struct, view \\ nil, fields)
  def render_row(nil, _, _), do: []

  # render list of struct
  def render_row(structs, view, fields) when is_list(structs) do
    Enum.map(structs, &render_row(&1, view, fields))
  end

  # render single struct
  def render_row(struct, view, fields) do
    Enum.map(fields, fn field -> render_cell(struct, view, field) end)
  end

  @doc """
  render cell without view, in this case, field must be a tuple of
  - `{field, render_fn, format}`
  - `{field, render_fn}`
  - `{field, format}`
  - `field_name`
  """
  def render_cell(struct, nil, field) do
    case field do
      {field, render_fn, format} when is_function(render_fn) ->
        value = render_fn.(field, struct)
        [value | format]

      {field, render_fn} when is_function(render_fn) ->
        render_fn.(field, struct)

      {field, format} when is_list(format) ->
        [Map.get(struct, field) | format]

      field when is_atom(field) ->
        Map.get(struct, field)

      _ ->
        nil
    end
  end

  @doc """
  render cell with a view, view must define `render_cell/2` for each field
  field definition format:
  - `{field_name, format}`
  - `field_name`
  """
  def render_cell(struct, view, field) do
    # if fields is not empty and render_field/2 is not defined, raise exception
    if not Kernel.function_exported?(view, :render_cell, 2) do
      raise "render_cell/2 is not defined in #{view}"
    else
      case field do
        {field_name, format} when is_list(format) ->
          value = view.render_cell(field_name, struct)
          [value | format]

        field_name when is_atom(field_name) ->
          view.render_cell(field_name, struct)

        _ ->
          nil
      end
    end
  end
end
