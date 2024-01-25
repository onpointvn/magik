defmodule SoiTest do
  use ExUnit.Case

  doctest Magik.Soi

  test "fetch data from map" do
    data = %{users: [%{name: "user1", is_active: true}, %{name: "user2", is_active: false}]}
    assert Magik.Soi.fetch(data, [:users, 0, :name]) == {:ok, "user1"}
    assert Magik.Soi.fetch(data, [:users, 1, :name]) == {:ok, "user2"}
    assert Magik.Soi.fetch(data, [:users, 0, :is_active]) == {:ok, true}
    assert Magik.Soi.fetch(data, [:users, 1, :is_active]) == {:ok, false}
  end

  test "fetch data match map criterials" do
    data = %{users: [%{name: "user1", is_active: true}, %{name: "user2", is_active: false}]}
    assert Magik.Soi.fetch(data, [:users, %{is_active: true}, :name]) == {:ok, "user1"}
    assert Magik.Soi.fetch(data, [:users, %{is_active: false}, :name]) == {:ok, "user2"}
  end

  test "fetch data match function criterials" do
    data = %{users: [%{name: "user1", is_active: true}, %{name: "user2", is_active: false}]}

    assert Magik.Soi.fetch(data, [:users, fn user -> user.name == "user1" end, :name]) ==
             {:ok, "user1"}

    assert Magik.Soi.fetch(data, [:users, fn user -> user.name == "user2" end, :name]) ==
             {:ok, "user2"}
  end

  test "get data from map" do
    data = %{users: [%{name: "user1", is_active: true}, %{name: "user2", is_active: false}]}
    assert Magik.Soi.get(data, [:users, 0, :name]) == "user1"
    assert Magik.Soi.get(data, [:users, 1, :name]) == "user2"
    assert Magik.Soi.get(data, [:users, 0, :is_active]) == true
    assert Magik.Soi.get(data, [:users, 1, :is_active]) == false
  end

  test "extract data from map" do
    data = %{
      users: [
        %{name: "user1", is_active: true, languages: ["js", "html"]},
        %{name: "user2", is_active: false, languages: ["elixir", "sql"]}
      ]
    }

    # extract all users name
    assert Magik.Soi.extract(data, [:users, "*", :name]) == ["user1", "user2"]
    # extract name of all users is_active
    assert Magik.Soi.extract(data, [:users, & &1.is_active, :name]) == ["user1"]
    assert Magik.Soi.extract(data, [:users, %{is_active: true}, :name]) == ["user1"]

    # extract all users languages
    assert Magik.Soi.extract(data, [:users, "*", :languages]) == [
             ["js", "html"],
             ["elixir", "sql"]
           ]

    # get first user languages
    assert Magik.Soi.extract(data, [:users, 0, :languages]) == [["js", "html"]]
  end

  test "extract data with not existing field return empty list" do
    data = %{
      users: [
        %{name: "user1", is_active: true, languages: ["js", "html"]},
        %{name: "user2", is_active: false, languages: ["elixir", "sql"]}
      ]
    }

    assert Magik.Soi.extract(data, [:users, "*", :not_exist_field]) == []
  end

  test "extract data of empty map" do
    data = %{}
    assert Magik.Soi.extract(data, [:users, "*", :name]) == []
  end

  #   test "extract data from nil map raise error" do
  #     assert_raise(Magik.Soi.extract(nil, [:users, "*", :name]) == [])
  #   end

  test "data clean nil value" do
    data = %{
      users: [
        %{name: "user1", is_active: true, languages: ["js", "html", nil]},
        %{name: nil, is_active: false, languages: ["elixir", "sql"]}
      ]
    }

    result = Magik.Soi.clean_nil(data)

    assert result == %{
             users: [
               %{name: "user1", is_active: true, languages: ["js", "html"]},
               %{is_active: false, languages: ["elixir", "sql"]}
             ]
           }
  end
end
