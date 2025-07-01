# Advanced Configuration

By default, LogHog starts its own supervision tree and attaches a logger handler.
This behavior is configured by the `:log_hog` option in your global configuration:

```elixir
config :log_hog,
  enable: true,
  enable_error_tracking: true,
  public_url: "https://us.i.posthog.com",
  api_key: "phc_asdf"
  ...
```

However, in certain cases you might want to run this supervision tree yourself.
You can do this by disabling the default supervisor and adding `LogHog.Supervisor`
to your application tree with its own configuration:

```elixir
# config.exs

config :log_hog, enable: false

config :my_app, :log_hog,
  public_url: "https://us.i.posthog.com",
  api_key: "phc_asdf"

# application.ex

defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    log_hog_config = Application.fetch_env!(:my_app, :log_hog) |> LogHog.Config.validate!()
    
    :logger.add_handler(:log_hog, LogHog.Handler, %{config: log_hog_config})

    children = [
      {LogHog.Supervisor, log_hog_config}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Multiple Instances

In even more advanced cases, you might want to interact with more than one
PostHog project. In this case, you can run multiple LogHog supervision trees,
one of which can be the default one:

```elixir
# config.exs
config :log_hog,
  public_url: "https://us.i.posthog.com",
  api_key: "phc_key1"

config :my_app, :another_log_hog,
  public_url: "https://us.i.posthog.com",
  api_key: "phc_key2",
  supervisor_name: AnotherLogHog
  
# application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    log_hog_config = Application.fetch_env!(:my_app, :another_log_hog) |> LogHog.Config.validate!()
    
    children = [
      {LogHog.Supervisor, log_hog_config}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

Then, each function in the `LogHog` module accepts an optional first argument with
the name of the LogHog supervisor tree that will process the capture:

```elixir
iex> LogHog.capture(AnotherLogHog, "user_signed_up", %{distinct_id: "user123"})
```
