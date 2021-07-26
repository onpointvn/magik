defmodule Magik.ExcelView do
  @moduledoc """
  ExcelView helps to render Excel content for `Elixlsx` easier

  ## Use as a view

  ```elixir
    defmodule TestView do
      use Magik.ExcelView

      # render list or stream
      def render_content(user_list) do
        fields = [:name, :email, :age, :is_teenager]
        render_row(user_list, fields)

        # or render with assigns
        render_row(user_list, fields, %{message: "hi"})
      end

      # by default raw value of the item is used
      # here we define custom render for a specific view
      def render_field(:is_teenager, user) do
        if user.age < 20, do: "YES", else: "NO"
      end
    end
  ```
  **Fields**
  Could be a real field in the data or virtual field. If it's virtual field, you have to define a custom render function as described below.
  A field could be:
  - `field_name` Ex: `:name`
  - `{field, format}` Ex: `{:name, bold: true, italic: true}`

  **Custom render**
  You can define custom render function for specific field
  - `render_field(field_name, struct)`
  - `render_field(field_name, struct, assigns)`


  ## Use without view
  `ExcelView` can be used without defining a view.

  ```elixir
  def render_excel_data (user_list) do
    fields = [
      :name,
      {:email, bold: true},
      :age,
      {:is_teenager, &/is_teenager/1}
    ]
    Magik.ExcelView.rener_row(user_list, fields)

    # or with assigns
    Magik.ExcelView.rener_row(user_list, fields, %{custom: "custom"})
  end

  def is_teenager(user) do
    if user.age < 20, do: "YES", else: "NO"
  end
  ```

  A field could be:
  - `field_name` Ex: `:name`
  - `{field, format}` Ex: `{:name, bold: true, italic: true}`
  - `{field, render_func}`
  - `{field, render_func, format}`

  Render functions would be accepted
  - `func(struct)`
  - `func(field_name, struct)`
  """

  defmacro __using__(_) do
    quote do
      @before_compile Magik.ExcelView
      def render_row(struct, fields, assigns \\ []) do
        Magik.ExcelView.render_row(struct, __MODULE__, fields, assigns)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def render_field(field, struct, _), do: Map.get(struct, field)
    end
  end

  def render_row(struct, view \\ nil, fields, assigns \\ [])
  def render_row(nil, _, _, _), do: []

  # render list of struct
  def render_row(structs, view, fields, assigns) when is_list(structs) do
    Enum.map(structs, &render_row(&1, view, fields, assigns))
  end

  # render single struct
  def render_row(struct, view, fields, assigns) when is_list(fields) do
    Enum.map(fields, fn field -> render_cell(struct, view, field, assigns) end)
  end

  def render_row(struct, fields, assigns, _) do
    Enum.map(fields, fn field -> render_cell(struct, nil, field, assigns) end)
  end

  def render_cell(struct, view, field, assigns \\ [])

  @doc """
  render cell without view, in this case, field must be a tuple of
  - `{field, render_fn, format}`
  - `{field, render_fn}`
  - `{field, format}`
  - `field_name`


  render cell with a view, view must define `render_cell/2` for each field
  field definition format:
  - `{field_name, format}`
  - `field_name`
  """
  def render_cell(struct, nil, field, assigns) do
    assigns = Map.new(assigns)

    case field do
      {field, format} when is_list(format) ->
        value = render_cell(struct, nil, field, assigns)
        [value | format]

      field when is_atom(field) ->
        Map.get(struct, field)

      render_fn when is_function(render_fn, 1) ->
        render_fn.(struct)

      render_fn when is_function(render_fn, 2) ->
        render_fn.(struct, assigns)

      _ ->
        nil
    end
  end

  def render_cell(struct, view, field, assigns) when is_atom(view) do
    assigns = Map.new(assigns)

    case field do
      {field_name, format} when is_list(format) ->
        value = render_cell(struct, view, field_name, assigns)
        [value | format]

      field_name when is_atom(field_name) ->
        view.render_field(field_name, struct, assigns)

      _ ->
        nil
    end
  end
end
