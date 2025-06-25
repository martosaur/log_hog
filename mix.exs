defmodule LogHog.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/martosaur/log_hog"

  def project do
    [
      app: :log_hog,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {LogHog.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_env), do: ["lib"]

  defp package do
    [
      description: "PostHog Error Tracking for Elixir",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md"
      ],
      assets: %{
        "assets" => "assets"
      },
      groups_for_modules: [
        Integrations: [LogHog.Integrations.Plug]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, "~> 1.1"},
      {:req, "~> 0.5.10"},
      {:logger_json, "~> 7.0"},
      {:logger_handler_kit, "~> 0.3", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false}
    ]
  end
end
