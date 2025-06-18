defmodule LogHog.Handler do
  @moduledoc """
  [`logger handler`](https://www.erlang.org/doc/apps/kernel/logger_chapter.html#handlers)
  """
  @behaviour :logger_handler

  alias LogHog.Context

  @impl :logger_handler
  def log(log_event, %{config: config}) do
    cond do
      get_in(log_event, [:meta, :crash_reason]) ->
        event = to_event(log_event, config)
        LogHog.Sender.send(event, config.supervisor_name)

      is_nil(config.capture_level) ->
        :ok

      Logger.compare_levels(log_event.level, config.capture_level) in [:gt, :eq] ->
        event = to_event(log_event, config)
        LogHog.Sender.send(event, config.supervisor_name)

      true ->
        :ok
    end
  end

  defp to_event(log_event, config) do
    exception =
      Enum.reduce(
        [&type/1, &value/1, &stacktrace(&1, config.in_app_modules)],
        %{mechanism: %{handled: true, type: "generic"}},
        fn fun, acc ->
          Map.merge(acc, fun.(log_event))
        end
      )

    metadata =
      log_event.meta
      |> Map.take([:distinct_id | config.metadata])
      |> Map.drop(["$exception_list"])
      |> LoggerJSON.Formatter.RedactorEncoder.encode([])

    %{
      event: "$exception",
      properties:
        Context.get()
        |> Map.merge(config.global_context)
        |> Map.merge(%{
          distinct_id: "unknown",
          "$exception_list": [exception]
        })
        |> Map.merge(metadata)
    }
  end

  defp type(log_event) do
    log_event
    |> do_type()
    |> String.split("\n")
    |> then(fn [type | _] -> %{type: type} end)
  end

  defp do_type(%{meta: %{crash_reason: {reason, _}}}) when is_exception(reason),
    do: inspect(reason.__struct__)

  defp do_type(%{meta: %{crash_reason: {{:nocatch, throw}, _}}}),
    do: Exception.format_banner(:throw, throw)

  defp do_type(%{meta: %{crash_reason: {reason, _}}}),
    do: Exception.format_banner(:exit, reason)

  defp do_type(%{msg: {:string, chardata}}), do: IO.iodata_to_binary(chardata)

  defp do_type(%{msg: {:report, report}, meta: %{report_cb: report_cb}})
       when is_function(report_cb, 1) do
    {io_format, data} = report_cb.(report)

    io_format
    |> :io_lib.format(data)
    |> IO.iodata_to_binary()
  end

  defp do_type(%{msg: {:report, report}}), do: inspect(report)

  defp do_type(%{msg: {io_format, data}}),
    do: io_format |> :io_lib.format(data) |> IO.iodata_to_binary()

  defp value(%{meta: %{crash_reason: {reason, stacktrace}}}) when is_exception(reason),
    do: %{value: Exception.format_banner(:error, reason, stacktrace)}

  defp value(%{meta: %{crash_reason: {{:nocatch, throw}, stacktrace}}}),
    do: %{value: Exception.format_banner(:throw, throw, stacktrace)}

  defp value(%{meta: %{crash_reason: {reason, stacktrace}}}),
    do: %{value: Exception.format_banner(:exit, reason, stacktrace)}

  defp value(%{msg: {:string, chardata}}), do: %{value: IO.iodata_to_binary(chardata)}

  defp value(%{msg: {:report, report}, meta: %{report_cb: report_cb}})
       when is_function(report_cb, 1) do
    {io_format, data} = report_cb.(report)
    io_format |> :io_lib.format(data) |> IO.iodata_to_binary() |> then(&%{value: &1})
  end

  defp value(%{msg: {:report, report}}), do: %{value: inspect(report)}

  defp value(%{msg: {io_format, data}}),
    do: io_format |> :io_lib.format(data) |> IO.iodata_to_binary() |> then(&%{value: &1})

  defp stacktrace(%{meta: %{crash_reason: {_reason, [_ | _] = stacktrace}}}, in_app_modules) do
    frames =
      for {module, function, arity_or_args, location} <- stacktrace do
        in_app = module in in_app_modules

        %{
          platform: "custom",
          lang: "elixir",
          function: Exception.format_mfa(module, function, arity_or_args),
          filename: Keyword.get(location, :file, []) |> IO.chardata_to_string(),
          lineno: Keyword.get(location, :line),
          module: inspect(module),
          in_app: in_app,
          resolved: true
        }
      end

    %{
      stacktrace: %{
        type: "raw",
        frames: frames
      }
    }
  end

  defp stacktrace(_event, _), do: %{}
end
