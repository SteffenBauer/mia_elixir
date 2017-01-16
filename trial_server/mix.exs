defmodule TrialServer.Mixfile do
  use Mix.Project

  def project do
    [app: :trial_server,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {TrialServer, []}]
  end

  defp deps do
    []
  end
end
