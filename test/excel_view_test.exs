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

  test "render field with render_field/3" do
    assert ["product", "sku.001", "100000d", "Cat"] ==
             render_row(@data, [:name, :sku, :price, :category], %{
               category: %{name: "Cat"}
             })
  end

  test "render row list" do
    assert [["product", "sku.001", "100000d"] | _] = render_row([@data, @data, @data], [:name, :sku, :price])
  end

  test "render with style" do
    assert [["product", bold: true], "sku.001", "100000d"] = render_row(@data, [{:name, bold: true}, :sku, :price])
  end

  def render_field(:price, struct, _) do
    "#{struct.price}d"
  end

  def render_field(:made_in, struct, _) do
    struct.country
  end

  def render_field(:quantity, struct, _) do
    "#{struct.quantity} box"
  end

  def render_field(:category, _struct, %{category: cat}) do
    cat.name
  end
end
