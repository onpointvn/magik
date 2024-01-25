defmodule Magik.CryptoTest do
  use ExUnit.Case

  alias Magik.Crypto

  describe "test aes crypt functions" do
    test "generate secret should be 32 byte" do
      assert 32 =
               Crypto.generate_secret()
               |> Base.decode64!()
               |> byte_size()
    end

    test "encrypt and decrypt" do
      key = Crypto.generate_secret()
      assert {:ok, _cipher} = Crypto.encrypt("hello", key)
      assert cipher = Crypto.encrypt!("hello", key)
      assert "hello" = Crypto.decrypt!(cipher, key)
      assert {:ok, "hello"} = Crypto.decrypt(cipher, key)
    end

    test "encrypt and decrypt with empty key" do
      assert {:error, "Bad secret key"} = Crypto.encrypt("hello", "")
      assert {:error, "Bad secret key"} = Crypto.decrypt("hello", "")
    end

    test "encrypt! and decrypt! with empty key" do
      assert_raise RuntimeError, fn ->
        Crypto.encrypt!("hello", "")
      end

      assert_raise RuntimeError, fn ->
        Crypto.decrypt!("hello", "")
      end
    end

    test "encrypt, decrypt with key differ 32byte" do
      assert {:error, "Bad secret key"} = Crypto.encrypt("hello", Base.encode64("123"))

      assert {:error, "Bad secret key"} = Crypto.encrypt("hello", Base.encode64("123123123123123123"))

      assert {:error, "Bad secret key"} = Crypto.decrypt(Base.encode64("hello"), Base.encode64("123"))

      assert {:error, "Bad secret key"} = Crypto.decrypt(Base.encode64("hello"), Base.encode64("123123123123123123"))
    end

    test "decrypt with bad data" do
      assert {:error, "Bad encrypted data"} = Crypto.decrypt(Base.encode64("hello"), Crypto.generate_secret())

      assert {:error, "Bad encrypted data"} = Crypto.decrypt("hello", Crypto.generate_secret())
    end
  end
end
