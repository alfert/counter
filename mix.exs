defmodule Counter.Mixfile do
  use Mix.Project

  def project do
    [
      app: :counter,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Counter.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:propcheck, "~> 1.0"},
      {:stream_data, path: "../stream_data", override: true},
      {:stream_code, path: "../stream_code"},
      {:type_class, "~> 1.2"}
    ]
  end
end
