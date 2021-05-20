defmodule Magik.JsonView do
  defmacro __using__(opts \\ []) do
    fields = Keyword.get(opts, :fields, [])
    custom_fields = Keyword.get(opts, :custom_fields, [])

    quote do
      def render_json(struct, fields, custom_fields, relationships) do
        Magik.JsonView.render_json(struct, __MODULE__,
          fields: unquote(fields) ++ fields,
          custom_fields: unquote(custom_fields) ++ custom_fields,
          relationships: relationships
        )
      end

      def render_view(struct, view, template) do
        Magik.JsonView.render_template(struct, view, template)
      end
    end
  end

  @moduledoc """
  Render a struct to a map with given options

  - `fields`: which fields are extract directly from struct
  - `custom_fields`: which fields are render using custom `render_field/2` function
  - `relationships`: a list of {field, view_module} defines which fields are rendered using another view


  Here is a sample view

      defmodule MyApp.PostView do
          use JsonView

          @fields [:title, :content, :excerpt, :cover]
          @custom_fields [:like_count]
          @relationships [author: MyApp.AuthorView]

          def render("post.json", %{post: post}) do

              # 1st way if `use JsonView`
              render_json(post, @fields, @custom_fields, @relationships)

              # 2nd way same as above
              JsonView.render_json(post, __MODULE__,
                  fields: @fields,
                  custom_fields: @custom_fields,
                  relationships: @relationships
              )

              # 3rd render manual
              post
              |> JsonView.render_fields(@fields)
              |> Map.merge(JsonView.render_custom_fields(post, __MODULE__, @custom_fields))
              |> Map.merge(JsonView.render_relationships(post, @relationships))
          end

          def render_field(:like_count, item) do
              # load like_count from some where
          end
      end

  """

  def render_json(nil, _, _), do: nil

  def render_json(struct, view, opts) when is_list(opts) do
    fields = Keyword.get(opts, :fields, [])
    custom_fields = Keyword.get(opts, :custom_fields, [])
    relationships = Keyword.get(opts, :relationships, [])

    struct
    |> render_fields(fields)
    |> Map.merge(render_custom_fields(struct, view, custom_fields))
    |> Map.merge(render_relationships(struct, relationships))
  end

  def render_fields(structs, fields) do
    Map.take(structs, fields)
  end

  @doc """
  Render field with custom render function
  View module must defines `render_field/2` function to render each custom field

      use JsonView

      def render_field(:is_success, item) do
        item.state > 3
      end

      render_custom_fields(struct, __MODULE__, [:is_success])

  """

  def render_custom_fields(struct, view \\ nil, fields) do
    # if fields is not empty and render_field/2 is not defined, raise exception

    fields
    |> Enum.map(fn
      {field, render_func} when is_function(render_func) ->
        {field, render_func.(struct)}

      field ->
        {field, view.render_field(field, struct)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Render relationship field for struct. `relationships` is a list of {field, view} for mapping render.
  For each field, call function `View.render()` to render json for relation object.

  Example relationships:

      relationships = [comments: CommentView, author: UserView]

  Result of `render_relationships(post, relationships)` equal to output of below code

      %{
          comments: CommentView.render_many(comments, CommentView, "comment.json"),
          autho: UserView.render_one(author, UserView, "user.json")
      }
  """
  def render_relationships(struct, relationships) when is_list(relationships) do
    Enum.map(relationships, fn {field, view} ->
      {field, render_relationship(struct, field, view)}
    end)
    |> Enum.into(%{})
  end

  # render a single relationship

  def render_relationship(struct, field, {view, template}) do
    references = Map.get(struct, field)
    render_template(references, view, template)
  end

  def render_relationship(struct, field, view) do
    references = Map.get(struct, field)
    name = relationship_name(view)
    render_template(references, view, "#{name}.json")
  end

  def render_template(struct, view, template) do
    case struct do
      %Ecto.Association.NotLoaded{} ->
        nil

      %{} ->
        Phoenix.View.render_one(struct, view, template)

      struct when is_list(struct) ->
        Phoenix.View.render_many(struct, view, template)

      _ ->
        nil
    end
  end

  # get relationship name. Ex: HeraWeb.ProductView -> product
  # this value is used to map assign when render relationship
  # render_one(product, HeraWeb.ProductView, "product.json")
  defp relationship_name(view) do
    view
    |> Module.split()
    |> Enum.map(&Phoenix.Naming.underscore/1)
    |> List.last()
    |> String.trim_trailing("_view")
  end
end
