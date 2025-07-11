defmodule LogHog.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import LogHog.Case
    end
  end

  def setup_supervisor(context) do
    Mox.stub_with(LogHog.API.Mock, LogHog.API.Stub)

    config =
      [
        public_url: "https://us.i.posthog.com",
        api_key: "my_api_key",
        api_client_module: LogHog.API.Mock,
        supervisor_name: context.test,
        capture_level: :info
      ]
      |> Keyword.merge(context[:config] || [])
      |> LogHog.Config.validate!()
      |> Map.put(:max_batch_time_ms, to_timeout(60_000))
      |> Map.put(:max_batch_events, 100)

    start_link_supervised!({LogHog.Supervisor, config})

    sender_pid =
      config.supervisor_name |> LogHog.Registry.via(LogHog.Sender) |> GenServer.whereis()

    context
    |> Map.put(:config, config)
    |> Map.put(:sender_pid, sender_pid)
  end

  def setup_logger_handler(%{config: config} = context) do
    big_config_override = Map.take(context, [:handle_otp_reports, :handle_sasl_reports, :level])

    {context, on_exit} =
      LoggerHandlerKit.Arrange.add_handler(
        context.test,
        LogHog.Handler,
        config,
        big_config_override
      )

    on_exit(on_exit)
    context
  end
end
