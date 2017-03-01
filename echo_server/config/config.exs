use Mix.Config

config :echo_server,
  port: 4080

config :logger,
  level: :debug

config :logger, :console,
  format: "$date $time [$level] $levelpad$message\n",
  colors: [info: :green]
