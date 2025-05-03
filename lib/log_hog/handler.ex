defmodule LogHog.Handler do
  @behaviour :logger_handler

  alias LogHog.API

  @impl :logger_handler
  def log(event, %{config: config}) do
    API.post_exception(config.api_client, %{
      distinct_id: get_in(event, [:meta, :distinct_id]) || "unknown",
      "$exception_list": [
        %{
          type: type(event),
          value: value(event),
          mechanism: %{handled: true, type: "generic"},
          stacktrace: stacktrace(event)
        }
      ]
    })

    :ok
  end

  def type(%{msg: {:string, chardata}}), do: IO.iodata_to_binary(chardata)

  def type(%{meta: %{crash_reason: {reason, _}}}) when is_exception(reason),
    do: Exception.format_banner(:error, reason)

  def type(%{meta: %{crash_reason: {{:nocatch, throw}, _}}}),
    do: Exception.format_banner(:throw, throw)

  def type(%{meta: %{crash_reason: {reason, _}}}),
    do: Exception.format_banner(:exit, reason)

  def type(%{msg: {:report, report}}), do: inspect(report)

  def type(%{msg: {io_format, data}}),
    do: io_format |> :io_lib.format(data) |> IO.iodata_to_binary()

  def value(%{meta: %{crash_reason: {reason, stacktrace}}}) when is_exception(reason),
    do: Exception.format_banner(:error, reason, stacktrace)

  def value(%{meta: %{crash_reason: {{:nocatch, throw}, stacktrace}}}),
    do: Exception.format_banner(:throw, throw, stacktrace)

  def value(%{meta: %{crash_reason: {reason, stacktrace}}}),
    do: Exception.format_banner(:exit, reason, stacktrace)

  def value(%{msg: {:report, report}, meta: %{report_cb: report_cb}})
      when is_function(report_cb, 1) do
    {io_format, data} = report_cb.(report)
    io_format |> :io_lib.format(data) |> IO.iodata_to_binary()
  end

  def value(%{msg: {:string, chardata}}), do: IO.iodata_to_binary(chardata)
  def value(%{msg: {:report, report}}), do: inspect(report)

  def value(%{msg: {io_format, data}}),
    do: io_format |> :io_lib.format(data) |> IO.iodata_to_binary()

  def stacktrace(%{meta: %{crash_reason: {_reason, stacktrace}}}) do
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
      type: "raw",
      frames: frames
    }
  end

  def stacktrace(_event), do: %{}
end
