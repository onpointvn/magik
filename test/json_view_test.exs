defmodule MagikTest.AddressView do
  use Magik.JsonView

  def render("address.json", %{address: address}) do
    render_json(address, [:ward, :district, :city], [], [])
  end
end

defmodule MagikTestJsonView do
  use ExUnit.Case

  use Magik.JsonView,
    fields: [:name],
    custom_fields: [{:has_email, fn data -> not is_nil(data[:email]) end}]

  @data %{
    name: "John Doe",
    age: 20,
    email: "test@gmail.com",
    address: %{
      ward: "Ben Nghe",
      district: "1",
      city: "HCM"
    }
  }

  test "render default field" do
    assert %{
             name: "John Doe",
             is_teenager: false,
             has_email: true
           } == render_json(@data, [], [:is_teenager], [])
  end

  test "render default custom field" do
    assert %{
             name: "John Doe",
             is_teenager: false,
             has_email: true
           } == render_json(@data, [], [:is_teenager], [])
  end

  test "render field" do
    assert %{
             name: "John Doe",
             age: 20,
             email: "test@gmail.com",
             has_email: true
           } == render_json(@data, [:name, :age, :email], [], [])
  end

  test "render custom field" do
    assert %{
             name: "John Doe",
             is_teenager: false,
             has_email: true
           } == render_json(@data, [:name], [:is_teenager], [])
  end

  test "override custom field" do
    assert %{
             name: "John Doe",
             has_email: "YES"
           } == render_json(@data, [:name], [:has_email], [])
  end

  def render_field(:is_teenager, data) do
    data.age < 20
  end

  def render_field(:has_email, data) do
    (is_nil(data.email) && "NO") || "YES"
  end
end
