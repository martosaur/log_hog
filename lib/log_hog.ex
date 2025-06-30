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
  def bare_capture(event, distinct_id, %{} = properties),
    do: bare_capture(__MODULE__, event, distinct_id, properties)

  @doc """
  Captures a single event without retrieving properties from context.

  Capture is a relatively lightweight operation. The event is prepared
  synchronously and then sent to LogHog workers to be batched together with
  other events and sent over the wire.

  ## Examples

  Capture simple event:

      LogHog.bare_capture("event captured", "user123")
      
  Capture event with properies:

      LogHog.bare_capture("event captures", "user123", %{backend: "Phoenix"})
      
  Capture through a named LogHog instance:

      LogHog.bare_capture(MyLogHog, "event_captures", "user123")
  """
  def bare_capture(name \\ __MODULE__, event, distinct_id, properties \\ %{}) do
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

  @doc false
  def capture(event, %{} = properties),
    do: capture(__MODULE__, event, properties)

  @doc """
  Captures a single event.

  Any context previously set will be included in the event properties. Note that
  `distinct_id` is still required.

  ## Examples

  Set context and capture event:

      LogHog.set_context(%{distinct_id: "user123", "$feature/my-feature-flag": true})
      LogHog.capture("job started", %{job_name: "JobName"})
      
  Set context and capture event through a named LogHog instance:

      LogHog.set_context(MyLogHog, %{distinct_id: "user123", "$feature/my-feature-flag": true})
      LogHog.capture(MyLogHog, "job started", %{job_name: "JobName"})
  """
  def capture(name \\ __MODULE__, event, properties \\ %{}) do
    context =
      name
      |> get_event_context(event)
      |> Map.merge(properties)

    case Map.pop(context, :distinct_id) do
      {nil, _} -> {:error, :missing_distinct_id}
      {distinct_id, properties} -> bare_capture(name, event, distinct_id, properties)
    end
  end

  def get_feature_flag(name \\ __MODULE__, distinct_id_or_body) do
    body =
      case distinct_id_or_body do
        %{} = body -> body
        distinct_id -> %{distinct_id: distinct_id}
      end

    config = config(name)

    case LogHog.API.flags(config.api_client, body) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, resp} -> {:error, resp}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Set context for the current process.

  ## Examples

  Set and retrieve context for current process:

      > LogHog.set_context(%{foo: "bar"})
      > LogHog.get_context()
      %{foo: "bar"}

  Set and retrieve context for a named LogHog instance:

      > LogHog.set_context(MyLogHog, %{foo: "bar"})
      > LogHog.get_context(MyLogHog)
      %{foo: "bar"}
  """
  def set_context(name \\ __MODULE__, context), do: LogHog.Context.set(name, :all, context)

  @doc """
  Set context for the current process scoped for a specific event.

  ## Examples

  Set and retrieve context scoped for event:

      > LogHog.set_event_context("$exception", %{foo: "bar"})
      > LogHog.get_event_context("$exception")
      %{foo: "bar"}
     
  Set and retrieve context for a specific event through a named LogHog instance:

      > LogHog.set_event_context(MyLogHog, "$exception", %{foo: "bar"})
      > LogHog.get_event_context(MyLogHog, "$exception")
      %{foo: "bar"}
  """
  def set_event_context(name \\ __MODULE__, event, context),
    do: LogHog.Context.set(name, event, context)

  @doc """
  Retrieves context for the current process.

  ## Examples

  Set and retrieve context for current process:

      > LogHog.set_context(%{foo: "bar"})
      > LogHog.get_context()
      %{foo: "bar"}
      
  Set and retrieve context for a named LogHog instance:

      > LogHog.set_context(MyLogHog, %{foo: "bar"})
      > LogHog.get_context(MyLogHog)
      %{foo: "bar"}
  """
  def get_context(name \\ __MODULE__), do: LogHog.Context.get(name, :all)

  @doc """
  Retrieves context for the current process scoped for a specific event.

  ## Examples

  Set and retrieve context scoped for event:

      > LogHog.set_event_context("$exception", %{foo: "bar"})
      > LogHog.get_event_context("$exception")
      %{foo: "bar"}
     
  Set and retrieve context for a specific event through a named LogHog instance:

      > LogHog.set_event_context(MyLogHog, "$exception", %{foo: "bar"})
      > LogHog.get_event_context(MyLogHog, "$exception")
      %{foo: "bar"}
  """
  def get_event_context(name \\ __MODULE__, event), do: LogHog.Context.get(name, event)
end
