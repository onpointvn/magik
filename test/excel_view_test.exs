defmodule TestExcelView do
  use ExUnit.Case

  use Magik.ExcelView

  @data %{
    name: "product",
    sku: "sku.001",
    price: 100_000,
    quantity: 100,
    country: "Vietnam"
  }

  test "render default field value" do
    assert ["product", "sku.001"] == render_row(@data, [:name, :sku])
  end

  test "render field with render_field/2" do
    assert ["product", "sku.001", "100000d"] == render_row(@data, [:name, :sku, :price])
  end

  test "render field with render_field/3" do
    assert ["product", "sku.001", "100000d", "Cat"] ==
             render_row(@data, [:name, :sku, :price, :category], %{
               category: %{name: "Cat"}
             })
  end

  test "render field priority with render_field/3" do
    assert ["product", "sku.001", "100000d", "100 bar"] ==
             render_row(@data, [:name, :sku, :price, :quantity], %{})
  end

  test "fallback to render_field/2 if render_field/3 not defined" do
    assert ["Vietnam"] ==
             render_row(@data, [:made_in], %{})
  end

  test "render row list" do
    assert [["product", "sku.001", "100000d"] | _] =
             render_row([@data, @data, @data], [:name, :sku, :price])
  end

  test "render with style" do
    assert [["product", bold: true], "sku.001", "100000d"] =
             render_row(@data, [{:name, bold: true}, :sku, :price])
  end

  def render_field(:price, struct) do
    "#{struct.price}d"
  end

  def render_field(:made_in, struct) do
    struct.country
  end

  def render_field(:quantity, struct) do
    "#{struct.quantity} box"
  end

  def render_field(:quantity, struct, _) do
    "#{struct.quantity} bar"
  end

  def render_field(:category, _struct, %{category: cat}) do
    cat.name
  end
end
