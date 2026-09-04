defmodule ZMex.MixProject do
  use Mix.Project

  @name "ZMex"
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
      links: %{"GitHub" => @repository}
    ]
  end

  defp docs() do
    [
      main: ZMex,
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
      {:dry_doc, "~> 0.1.1"}
    ]
  end

  def application, do: [extra_applications: extra_applications(Mix.env())]
  # enable :httpc use during tests to download any missing story files:
  defp extra_applications(:test), do: [:inets, :ssl]
  defp extra_applications(_env), do: []
end
