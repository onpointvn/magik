defmodule Magik.EctoType.EncryptedMap do
  @moduledoc """
  An Ecto Type to encrypt map before saving to database and decrypt after loading from database.
  Map data is encode to string before encrypted.
  So in database, this field must be defined as **text** field.

  **Config key**

  Generate secret key using: `Magik.Crypto.generate_secret`

      config :magik, :ecto_secret_key, "your key"
  """
  use Ecto.Type

  def type, do: :text

  def cast(value) when is_map(value) or is_nil(value) do
    {:ok, value}
  end

  def cast(_), do: :error

  def dump(nil), do: nil

  def dump(data) when is_map(data) do
    with {:ok, text} <- Jason.encode(data),
         {:ok, secret_key} <- Application.fetch_env(:magik, :ecto_secret_key),
         {:ok, data} <- Magik.Crypto.encrypt(text, secret_key) do
      {:ok, data}
    else
      _ -> :error
    end
  end

  def dump(_), do: :error

  def load(nil), do: nil

  def load(data) when is_binary(data) do
    secret_key = Application.fetch_env!(:magik, :ecto_secret_key)

    with {:ok, data} <- Magik.Crypto.decrypt(data, secret_key),
         {:ok, data} <- Jason.decode(data) do
      {:ok, data}
    else
      _ -> :error
    end
  end

  def load(_), do: :error

  def embed_as(_), do: :dump
end
