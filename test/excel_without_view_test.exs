defmodule ExcelWithoutViewTest do
  use ExUnit.Case

  alias Magik.ExcelView
  use Magik.ExcelView

  @data %{
    name: "product",
    sku: "sku.001",
    price: 100_000,
    quantity: 100,
    country: "Vietnam"
  }

  test "render default field value" do
    assert ["product", "sku.001"] == ExcelView.render_row(@data, [:name, :sku])
  end

  test "render field with render_field/1" do
    assert ["100000d"] == ExcelView.render_row(@data, [&render_price/1])
  end

  test "render field with render_field/3" do
    assert ["product", "sku.001", "Cat"] ==
             ExcelView.render_row(@data, [:name, :sku, &render_field(:category, &1, &2)], %{
               category: %{name: "Cat"}
             })
  end

  test "render row list" do
    assert [["product", "sku.001", 100_000] | _] =
             ExcelView.render_row([@data, @data, @data], [:name, :sku, :price])
  end

  test "render with style" do
    assert [["product", bold: true], "sku.001", "100000d"] =
             ExcelView.render_row(@data, [{:name, [bold: true]}, :sku, &render_price/1])
  end

  def render_price(struct) do
    "#{struct.price}d"
  end

  def render_field(:price, struct) do
    "#{struct.price}d"
  end

  def render_field(:made_in, struct) do
    struct.country
  end

  def render_field(:category, _struct, %{category: cat}) do
    cat.name
  end
end
