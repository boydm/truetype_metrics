#
#  Created by Boyd Multerer on 24/02/2019.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule TruetypeMetrics.MixProject do
  use Mix.Project

  def project do
    [
      app: :truetype_metrics,
      version: "0.3.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      # { :font_metrics, git: "https://github.com/boydm/font_metrics.git" }
      { :font_metrics, path: "../font_metrics" }
    ]
  end
end
