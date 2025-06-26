defmodule LogHog do
  @doc """
  Returns configuration map for a named `LogHog` supervisor

  ## Example

  Retrieve the default `LogHog` instance config:

      %{supervisor_name: LogHog} = LogHog.config()
      
  Retrieve named instance config:

      %{supervisor_name: MyLogHog} = LogHog.config(MyLogHog)
  """
  def config(name \\ __MODULE__), do: LogHog.Registry.config(name)

  @doc false
  def capture(event, distinct_id, %{} = properties),
    do: capture(__MODULE__, event, distinct_id, properties)

  @doc """
  Captures a single event

  Capture is a relatively lightweight operation. The event is prepared
  synchronously and then sent to LogHog workers to be batched together with
  other events and sent over the wire.

  ## Examples

  Capture simple event:

      LogHog.capture("event captured", "user123")
      
  Capture event with properies:

      LogHog.capture("event captures", "user123", %{backend: "Phoenix"})
      
  Capture through a named LogHog instance:

      LogHog.capture(MyLogHog, "event_captures", "user123")
  """
  def capture(name \\ __MODULE__, event, distinct_id, properties \\ %{}) do
    config = LogHog.Registry.config(name)
    properties = Map.merge(properties, config.global_properties)

    event = %{
      event: event,
      distinct_id: distinct_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      properties: properties
    }

    LogHog.Sender.send(event, name)
  end
end
