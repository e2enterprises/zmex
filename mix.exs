defmodule Zmex.MixProject do
  use Mix.Project

  @name "Zmex"
  @version "0.1.1"
  @repository "https://github.com/e2enterprises/zmex"

  defp description() do
    "IF by NIF: Call a Rust Z-Machine from Elixir and run classic text-adventure games (Inform v4, v5, v8)"
  end

  def project do
    [
      app: :zmex,
      description: description(),
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      deps: deps(),

      # Docs (see https://github.com/elixir-lang/ex_doc)
      name: @name,
      source_url: @repository,
      homepage_url: @repository
    ]
  end

  defp package() do
    [
      maintainers: ["Evan Campbell Purcer"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repository},
      files:
        default_files() ++
          [
            "native/encrusted_nif/Cargo.toml",
            "native/encrusted_nif/Cargo.lock",
            "native/encrusted_nif/src",
            "native/encrusted_nif/encrusted-heart/Cargo.toml",
            "native/encrusted_nif/encrusted-heart/Cargo.lock",
            "native/encrusted_nif/encrusted-heart/src",
            "native/encrusted_nif/encrusted-heart/tests/advent.z3",
            "native/encrusted_nif/encrusted-heart/LICENSE"
          ]
      # Extend default :files list to include Rust source code necessary
      # to build Encrusted Heart NIFs.
    ]
  end

  def default_files() do
    # From Hex.Package: https://github.com/hexpm/hex/blob/main/lib/hex/package.ex#L4
    ~w(lib priv .formatter.exs mix.exs README* LICENSE*)
  end

  defp docs() do
    [
      main: Zmex,
      # TODO
      # logo: nil
      before_closing_head_tag: &DryDoc.before_closing_head_tag_hide_pages_tab/1,
      before_closing_body_tag: &DryDoc.before_closing_body_tag_expand_sections_list/1
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.38.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dry_doc, "~> 0.1.2"}
    ]
  end

  def application, do: [extra_applications: extra_applications(Mix.env())]
  # enable :httpc use during tests to download any missing story files:
  defp extra_applications(:test), do: [:inets, :ssl]
  defp extra_applications(_env), do: []
end
