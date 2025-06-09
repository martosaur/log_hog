import Config

config :log_hog, enable: false

config :log_hog, :integration_config,
  public_url: "https://us.i.posthog.com",
  api_key: "my key",
  metadata: [:extra],
  capture_level: :info
