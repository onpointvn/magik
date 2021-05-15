use Mix.Config

config :magik, :telegram_noti,
  bot_token: "",
  conversations: [
    default: "-449089759",
    admin: "-553421733"
  ]

config :tesla, adapter: Tesla.Adapter.Hackney
