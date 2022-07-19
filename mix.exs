defmodule Soyaki.MixProject do
  use Mix.Project

  @source_url "https://github.com/konstantin-aa/soyaki"
  def project do
    [
      app: :soyaki,
      version: "0.1.0",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      description: description(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Soyaki.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp description do
    "A udp server that provides abstractions over sessions."
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Konstantin Astafurov"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
