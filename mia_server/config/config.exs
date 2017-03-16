use Mix.Config

config :mia_server,
  port: 4080,
  timeout: 200

config :logger,
  level: :warn

config :logger, :console,
  format: "$date $time [$level] $levelpad$message\n",
  colors: [info: :green]
