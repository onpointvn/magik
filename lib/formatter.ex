defmodule Magik.Formatter do
  @moduledoc """
  Provides functions to format value to string
  """

  @doc """
  Format number to thousand seperated string

  ## Parameters
    - `number`: integer number
    - `separator`: thousand separator character. Default is `.`

  ## Example
      iex> Magik.Formatter.format_thousand("1232321", ".")
      1.232.321
  """
  def format_thousand(number, separator \\ ".") do
    Regex.replace(~r/(\d)(?=(\d{3})+(?!\d))/, to_string(number), "\\1#{separator}")
  end

  @doc """
  Format currency value to thousand separated string

  ## Parameters
  - `number`: integer number
  - `opts`: list of format options
    - `thousand_separator`: thousand separator character. Default is `,`
    - `currency`: currency character. Default is "đ"

  ## Example
  iex> Magik.Formatter.format_currency("1232321", thousand_separator: ".", currency: "$")
  1.232.321$
  """
  @default_separator ","
  @default_currency "đ"
  def format_currency(number, opts \\ []) do
    separator = Keyword.get(opts, :thousand_separator, @default_separator)
    currency = Keyword.get(opts, :currency, @default_currency)
    "#{format_thousand(number, separator)}#{currency}"
  end
end
