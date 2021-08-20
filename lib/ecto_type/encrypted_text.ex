defmodule Magik.EctoType.EncryptedText do
  @moduledoc """
  An Ecto Type to encrypt text before saving to database and decrypt after loading from database.

  **Config key**

  Generate secret key using: `Magik.Crypto.generate_secret`

      config :magik, :ecto_secret_key, "your key"
  """
  use Ecto.Type

  def type, do: :text

  def cast(value) when is_binary(value) do
    {:ok, value}
  end

  def cast(_), do: :error

  def dump(nil), do: nil

  def dump(data) when is_binary(data) do
    with {:ok, secret_key} <- Application.fetch_env(:magik, :ecto_secret_key),
         {:ok, data} <- Magik.Crypto.encrypt(data, secret_key) do
      {:ok, data}
    else
      _ -> :error
    end
  end

  def dump(_), do: :error

  def load(nil), do: nil

  def load(data) when is_binary(data) do
    secret_key = Application.fetch_env!(:magik, :ecto_secret_key)

    case Magik.Crypto.decrypt(data, secret_key) do
      {:error, _} -> :error
      ok -> ok
    end
  end

  def load(_), do: :error

  def embed_as(_), do: :dump
end
