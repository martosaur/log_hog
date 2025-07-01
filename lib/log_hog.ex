defmodule LogHog do
  @typedoc "Name under which an instance of LogHog supervision tree is registered."
  @type supervisor_name() :: atom()

  @typedoc "Event name, such as `\"user_signed_up\"` or `\"$create_alias\"`"
  @type event() :: String.t()

  @typedoc "string representing distinct ID"
  @type distinct_id() :: String.t()

  @typedoc """
  Map representing event properties.

  Note that it __must__ be JSON-serializable.
  """
  @type properties() :: %{optional(String.t()) => any(), optional(atom()) => any()}

  @doc """
  Returns the configuration map for a named `LogHog` supervisor.

  ## Examples

  Retrieve the default `LogHog` instance config:

      %{supervisor_name: LogHog} = LogHog.config()
      
  Retrieve named instance config:

      %{supervisor_name: MyLogHog} = LogHog.config(MyLogHog)
  """
  @spec config(supervisor_name()) :: LogHog.Config.config()
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

  Capture a simple event:

      LogHog.bare_capture("event_captured", "user123")
      
  Capture an event with properties:

      LogHog.bare_capture("event_captured", "user123", %{backend: "Phoenix"})
      
  Capture through a named LogHog instance:

      LogHog.bare_capture(MyLogHog, "event_captured", "user123")
  """
  @spec bare_capture(supervisor_name(), event(), distinct_id(), properties()) :: :ok
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

  Set context and capture an event:

      LogHog.set_context(%{distinct_id: "user123", "$feature/my-feature-flag": true})
      LogHog.capture("job_started", %{job_name: "JobName"})
      
  Set context and capture an event through a named LogHog instance:

      LogHog.set_context(MyLogHog, %{distinct_id: "user123", "$feature/my-feature-flag": true})
      LogHog.capture(MyLogHog, "job_started", %{job_name: "JobName"})
  """
  @spec capture(supervisor_name(), event(), properties()) :: :ok | {:error, :missing_distinct_id}
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

  @spec get_feature_flag(supervisor_name(), distinct_id() | map()) :: LogHog.API.Client.response()
  def get_feature_flag(name \\ __MODULE__, distinct_id_or_body) do
    body =
      case distinct_id_or_body do
        %{} = body -> body
        distinct_id -> %{distinct_id: distinct_id}
      end

    config = config(name)
    LogHog.API.flags(config.api_client, body)
  end

  @doc """
  Sets context for the current process.

  ## Examples

  Set and retrieve context for the current process:

      > LogHog.set_context(%{foo: "bar"})
      > LogHog.get_context()
      %{foo: "bar"}

  Set and retrieve context for a named LogHog instance:

      > LogHog.set_context(MyLogHog, %{foo: "bar"})
      > LogHog.get_context(MyLogHog)
      %{foo: "bar"}
  """
  @spec set_context(supervisor_name(), properties()) :: :ok
  def set_context(name \\ __MODULE__, context), do: LogHog.Context.set(name, :all, context)

  @doc """
  Sets context for the current process scoped to a specific event.

  ## Examples

  Set and retrieve context scoped to an event:

      > LogHog.set_event_context("$exception", %{foo: "bar"})
      > LogHog.get_event_context("$exception")
      %{foo: "bar"}
     
  Set and retrieve context for a specific event through a named LogHog instance:

      > LogHog.set_event_context(MyLogHog, "$exception", %{foo: "bar"})
      > LogHog.get_event_context(MyLogHog, "$exception")
      %{foo: "bar"}
  """
  @spec set_event_context(supervisor_name(), event(), properties()) :: :ok
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
  @spec get_context(supervisor_name()) :: properties()
  def get_context(name \\ __MODULE__), do: LogHog.Context.get(name, :all)

  @doc """
  Retrieves context for the current process scoped to a specific event.

  ## Examples

  Set and retrieve context scoped to an event:

      > LogHog.set_event_context("$exception", %{foo: "bar"})
      > LogHog.get_event_context("$exception")
      %{foo: "bar"}
     
  Set and retrieve context for a specific event through a named LogHog instance:

      > LogHog.set_event_context(MyLogHog, "$exception", %{foo: "bar"})
      > LogHog.get_event_context(MyLogHog, "$exception")
      %{foo: "bar"}
  """
  @spec get_event_context(supervisor_name()) :: properties()
  def get_event_context(name \\ __MODULE__, event), do: LogHog.Context.get(name, event)
end
