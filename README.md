# LogHog

[LogHog Error Tracking](https://posthog.com/docs/error-tracking) for Elixir

> #### WIP {: .warning}
>
> The library is a work in progress! Don't use it yet.


What works:
* Sending basic log message to the server

What doesn't work:
* Everything else (metadata, stacktraces, batching, etc.)


## Getting Started

Add `LogHog` to the deps:

```elixir
def deps do
  [
    {:log_hog, "~> 0.0.1"}
  ]
end
```

Configure `LogHog` Application environment:

```elixir
config :log_hog,
  public_url: "https://us.i.posthog.com",
  api_key: "my_api_key"
```

Alternatively, you can attach `LogHog.Handler` yourself.