defmodule LogHog.Handler do
  @behaviour :logger_handler

  alias LogHog.API

  @impl :logger_handler
  def log(event, %{config: config}) do
    exception =
      Enum.reduce(
        [&type/1, &value/1, &stacktrace/1],
        %{mechanism: %{handled: true, type: "generic"}},
        fn fun, acc ->
          Map.merge(acc, fun.(event))
        end
      )

    API.post_exception(config.api_client, %{
      distinct_id: get_in(event, [:meta, :distinct_id]) || "unknown",
      "$exception_list": [exception]
    })

    :ok
  end

  def type(%{meta: %{crash_reason: {reason, _}}}) when is_exception(reason),
    do: %{type: Exception.format_banner(:error, reason)}

  def type(%{meta: %{crash_reason: {{:nocatch, throw}, _}}}),
    do: %{type: Exception.format_banner(:throw, throw)}

  def type(%{meta: %{crash_reason: {reason, _}}}),
    do: %{type: Exception.format_banner(:exit, reason)}

  def type(%{msg: {:string, chardata}}), do: %{type: IO.iodata_to_binary(chardata)}

  def type(%{msg: {:report, report}, meta: %{report_cb: report_cb}})
      when is_function(report_cb, 1) do
    {io_format, data} = report_cb.(report)

    io_format
    |> :io_lib.format(data)
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> then(fn [type | _] -> %{type: type} end)
  end

  def type(%{msg: {:report, report}}), do: %{type: inspect(report)}

  def type(%{msg: {io_format, data}}),
    do: io_format |> :io_lib.format(data) |> IO.iodata_to_binary() |> then(&%{type: &1})

  def value(%{meta: %{crash_reason: {reason, stacktrace}}}) when is_exception(reason),
    do: %{value: Exception.format_banner(:error, reason, stacktrace)}

  def value(%{meta: %{crash_reason: {{:nocatch, throw}, stacktrace}}}),
    do: %{value: Exception.format_banner(:throw, throw, stacktrace)}

  def value(%{meta: %{crash_reason: {reason, stacktrace}}}),
    do: %{value: Exception.format_banner(:exit, reason, stacktrace)}

  def value(%{msg: {:report, report}, meta: %{report_cb: report_cb}})
      when is_function(report_cb, 1) do
    {io_format, data} = report_cb.(report)
    io_format |> :io_lib.format(data) |> IO.iodata_to_binary() |> then(&%{value: &1})
  end

  def value(%{msg: {:string, chardata}}), do: %{value: IO.iodata_to_binary(chardata)}
  def value(%{msg: {:report, report}}), do: %{value: inspect(report)}

  def value(%{msg: {io_format, data}}),
    do: io_format |> :io_lib.format(data) |> IO.iodata_to_binary() |> then(&%{value: &1})

  def stacktrace(%{meta: %{crash_reason: {_reason, [_ | _] = stacktrace}}}) do
    frames =
      for {module, function, arity_or_args, location} <- stacktrace do
        %{
          lineno: Keyword.get(location, :line),
          filename: Keyword.get(location, :file) |> IO.chardata_to_string(),
          function: Exception.format_mfa(module, function, arity_or_args),
          module: inspect(module),
          in_app: true,
          platform: "python"
        }
      end

    %{
      stacktrace: %{
        type: "raw",
        frames: frames
      }
    }
  end

  def stacktrace(_event), do: %{}
end
