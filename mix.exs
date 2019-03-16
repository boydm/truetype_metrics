#
#  Created by Boyd Multerer on 24/02/2019.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule TruetypeMetrics.MixProject do
  use Mix.Project

  @app_name :truetype_metrics

  @version "0.3.0"

  @elixir_version "~> 1.8"
  @github "https://github.com/boydm/truetype_metrics"

  def project do
    [
      app: @app_name,
      version: "0.3.0",
      elixir: @elixir_version,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      { :font_metrics, path: "../font_metrics" },

      {:ex_doc, ">= 0.0.0", only: :dev},
      {:excoveralls, ">= 0.0.0", only: :test, runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:inch_ex, "~> 2.0", only: [:dev, :docs], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Mix.Tashs.TruetypeMetrics.html",
      source_ref: "v#{@version}",
      source_url: "https://github.com/boydm/truetype_metrics"
      # homepage_url: "http://kry10.com",
    ]
  end

  defp package do
    [
      name: @app_name,
      contributors: ["Boyd Multerer"],
      maintainers: ["Boyd Multerer"],
      licenses: ["Apache 2"],
      links: %{Github: @github},
    ]
  end

end
