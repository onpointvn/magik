defmodule Magik.Crypto do
  @moduledoc """
  Provide some basic encrypt/decrypt function
  """

  @aad "AES256GCM"
  @block_size 16

  @doc """
  Generates a random 16 byte and encode base64 secret key.
  """
  def generate_secret do
    :crypto.strong_rand_bytes(@block_size)
    |> Base.encode64()
  end

  @doc """
  Encrypt data using `:aes_128_cbc` mode, and return base64 encrypted string

      key = generate_secret()
      encrypt("hello", key)
  """
  @spec encrypt(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def encrypt(plaintext, secret_key) do
    with {:ok, secret_key} <- decode_key(secret_key) do
      iv = :crypto.strong_rand_bytes(@block_size)
      plaintext = pad(plaintext, @block_size)
      ciphertext = :crypto.crypto_one_time(:aes_128_cbc, secret_key, iv, plaintext, true)

      {:ok, Base.encode64(iv <> ciphertext)}
    end
  end

  @spec encrypt!(String.t(), String.t()) :: String.t()
  def encrypt!(plaintext, secret_key) do
    case encrypt(plaintext, secret_key) do
      {:ok, data} -> data
      {:error, msg} -> raise msg
    end
  end

  @doc """
  Decode cipher data which encrypted using `encrypt/2`

      key = generate_secret()
      {:ok, cipher} = encrypt("hello", key)
      decrypt(cipher, key)

  """
  @spec decrypt(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def decrypt(ciphertext, secret_key) do
    with {:ok, secret_key} <- decode_key(secret_key),
         {:ok, <<iv::binary-@block_size, ciphertext::binary>>} <- Base.decode64(ciphertext) do
      plaintext =
        :crypto.crypto_one_time(:aes_128_cbc, secret_key, iv, ciphertext, false)
        |> unpad

      {:ok, plaintext}
    else
      {:error, _} = err -> err
      _ -> {:error, "Bad encrypted data"}
    end
  end

  def decrypt!(ciphertext, secret_key) do
    case decrypt(ciphertext, secret_key) do
      {:ok, data} -> data
      {:error, msg} -> raise msg
    end
  end

  @doc """
  Encrypt data using `:aes_128_cbc` mode, and return base64 encrypted string

      key = generate_secret()
      encrypt_aead("hello", key)
  """
  @spec encrypt_aead(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def encrypt_aead(plaintext, secret_key) do
    with {:ok, secret_key} <- decode_key(secret_key) do
      iv = :crypto.strong_rand_bytes(@block_size)

      {ciphertext, ciphertag} =
        :crypto.crypto_one_time_aead(:aes_128_gcm, secret_key, iv, plaintext, @aad, true)

      {:ok, Base.encode64(iv <> ciphertag <> ciphertext)}
    end
  end

  @spec encrypt_aead!(String.t(), String.t()) :: String.t()
  def encrypt_aead!(plaintext, secret_key) do
    case encrypt_aead(plaintext, secret_key) do
      {:ok, data} -> data
      {:error, msg} -> raise msg
    end
  end

  @doc """
  Decode cipher data which encrypted using `encrypt/2`

      key = generate_secret()
      {:ok, cipher} = encrypt_aead("hello", key)
      decrypt_aead(cipher, key)

  """
  @spec decrypt_aead(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def decrypt_aead(ciphertext, secret_key) do
    with {:ok, secret_key} <- decode_key(secret_key),
         {:ok, <<iv::binary-@block_size, tag::binary-@block_size, ciphertext::binary>>} <-
           Base.decode64(ciphertext) do
      plaintext =
        :crypto.crypto_one_time_aead(:aes_128_gcm, secret_key, iv, ciphertext, @aad, tag, false)

      {:ok, plaintext}
    else
      {:error, _} = err -> err
      _ -> {:error, "Bad encrypted data"}
    end
  end

  @spec decrypt_aead!(String.t(), String.t()) :: String.t()
  def decrypt_aead!(ciphertext, secret_key) do
    case decrypt_aead(ciphertext, secret_key) do
      {:ok, data} -> data
      {:error, msg} -> raise msg
    end
  end

  defp decode_key(nil), do: {:error, "Bad secret key"}

  defp decode_key(key) do
    with {:ok, data} <- Base.decode64(key),
         true <- byte_size(data) == @block_size do
      {:ok, data}
    else
      _ ->
        {:error, "Bad secret key"}
    end
  end

  defp pad(data, block_size) do
    to_add = block_size - rem(byte_size(data), block_size)
    data <> :binary.copy(<<to_add>>, to_add)
  end

  defp unpad(data) do
    to_remove = :binary.last(data)
    :binary.part(data, 0, byte_size(data) - to_remove)
  end
end
