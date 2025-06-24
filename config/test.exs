import Config

config :log_hog, enable: false

if File.exists?("config/integration.exs"), do: import_config("integration.exs")
