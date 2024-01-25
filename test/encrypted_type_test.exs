defmodule EncryptedTypeTest do
  use ExUnit.Case

  alias Magik.EctoType.EncryptedMap
  alias Magik.EctoType.EncryptedText

  describe "test Encrypted text" do
    test "cast binary succes" do
      assert {:ok, "hello"} = EncryptedText.cast("hello")
    end

    test "cast not binary error" do
      assert :error = EncryptedText.cast(10)
    end

    test "dump nil return nil" do
      assert nil == EncryptedText.dump(nil)
    end

    test "dump data without key setting error" do
      Application.delete_env(:magik, :ecto_secret_key)
      assert :error = EncryptedText.dump("hello")
    end

    test "dump binary data key setting success" do
      Application.put_env(:magik, :ecto_secret_key, Magik.Crypto.generate_secret())
      assert {:ok, cipher} = EncryptedText.dump("hello")
      assert {:ok, "hello"} = EncryptedText.load(cipher)
    end

    test "dump not binary data key setting error" do
      assert :error = EncryptedText.dump(123)
    end

    test "load nil return nil" do
      assert nil == EncryptedText.load(nil)
    end

    test "load binary success" do
      Application.put_env(:magik, :ecto_secret_key, Magik.Crypto.generate_secret())
      assert {:ok, cipher} = EncryptedText.dump("hello")
      assert {:ok, "hello"} = EncryptedText.load(cipher)
    end

    test "loat not binary error" do
      assert :error = EncryptedText.load(123)
    end
  end

  describe "test Encrypted map" do
    test "cast map_size succes" do
      assert {:ok, %{a: 1}} = EncryptedMap.cast(%{a: 1})
    end

    test "cast not map error" do
      assert :error = EncryptedMap.cast(10)
    end

    test "dump nil return nil" do
      assert nil == EncryptedMap.dump(nil)
    end

    test "dump data without key setting error" do
      Application.delete_env(:magik, :ecto_secret_key)
      assert :error = EncryptedMap.dump(%{})
    end

    test "dump map data key setting success" do
      Application.put_env(:magik, :ecto_secret_key, Magik.Crypto.generate_secret())
      assert {:ok, cipher} = EncryptedMap.dump(%{})
      assert {:ok, %{}} = EncryptedMap.load(cipher)
    end

    test "dump not map data key setting error" do
      assert :error = EncryptedMap.dump(123)
    end

    test "load nil return nil" do
      assert nil == EncryptedMap.load(nil)
    end

    test "load map success" do
      Application.put_env(:magik, :ecto_secret_key, Magik.Crypto.generate_secret())
      assert {:ok, cipher} = EncryptedMap.dump(%{name: "hello"})
      assert {:ok, %{"name" => "hello"}} = EncryptedMap.load(cipher)
    end

    test "loat not map error" do
      assert :error = EncryptedMap.load(123)
    end
  end
end
