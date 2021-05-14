defmodule Magik.MixProject do
  use Mix.Project

  def project do
    [
      app: :magik,
      version: "0.2.0",
      build_path: "./_build",
      config_path: "./config/config.exs",
      deps_path: "./deps",
      lockfile: "./mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      name: "Magik",
      description: description(),
      source_url: "https://github.com/onpointvn/magik",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp package() do
    [
      maintainers: ["Dung Nguyen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/onpointvn/magik"}
    ]
  end

  defp description() do
    """
    It's cool to do some magics
    """
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.0", optional: true},
      {:plug, "~> 1.11", optional: true},
      {:phoenix, "~> 1.5", optional: true},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end
end
