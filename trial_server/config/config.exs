use Mix.Config

config :trial_server,
  port: 4080,
  trials: 5

config :logger,
  level: :warn

config :logger, :console,
  format: "$date $time [$level] $levelpad$message\n",
  colors: [info: :green]
