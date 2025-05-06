defmodule LogHog.IntegrationTest do
  require Config
  use ExUnit.Case, async: false

  require Logger

  @moduletag integration: true

  setup_all do
    {:ok, config} =
      Application.fetch_env!(:log_hog, :integration_config) |> LogHog.Config.validate()

    :logger.add_handler(:log_hog, LogHog.Handler, %{config: config})
  end

  setup %{test: test} do
    Logger.metadata(distinct_id: test)
  end

  test "log message" do
    Logger.info("Hello World!")
  end

  test "task exception" do
    LoggerHandlerKit.Act.task_error(:exception)
  end

  test "task throw" do
    LoggerHandlerKit.Act.task_error(:throw)
  end

  test "task exit" do
    LoggerHandlerKit.Act.task_error(:exit)
  end

  test "supervisor report" do
    Application.stop(:logger)
    Application.put_env(:logger, :handle_sasl_reports, true)
    Application.put_env(:logger, :level, :info)
    Application.start(:logger)

    on_exit(fn ->
      Application.stop(:logger)
      Application.put_env(:logger, :handle_sasl_reports, false)
      Application.delete_env(:logger, :level)
      Application.start(:logger)
    end)

    LoggerHandlerKit.Act.supervisor_progress_report(:failed_to_start_child)
  end
end
