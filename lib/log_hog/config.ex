defmodule LogHog.Config do
  @configuration_schema [
    enable: [
      type: :boolean,
      default: true,
      doc: "Automatically start LogHog?"
    ],
    public_url: [
      type: :string,
      required: true,
      doc: "i.e. https://us.i.posthog.com"
    ],
    api_key: [
      type: :string,
      required: true,
      doc: "Your PostHog API key"
    ],
    api_client_module: [
      type: :atom,
      default: LogHog.API.Client,
      doc: "API Client to use"
    ],
    supervisor_name: [
      type: :atom,
      default: LogHog,
      doc: "Name of the supervisor process running LogHog"
    ],
    metadata: [
      type: {:list, :atom},
      default: [],
      doc: "List of metadata keys to include in event properties"
    ],
    capture_level: [
      type: {:or, [{:in, Logger.levels()}, nil]},
      default: :error,
      doc:
        "Minimum level for logs that should be captured as errors. Errors with `crash_reason` are always captured."
    ]
  ]

  @compiled_schema NimbleOptions.new!(@configuration_schema)

  @moduledoc """
  LogHog configuration

  ## Configuration Schema

  #{NimbleOptions.docs(@compiled_schema)}
  """

  @type config() :: map()

  @doc """
  Reads and validates config from global application configuration
  """
  @spec read!() :: config() | :missing_config
  def read!() do
    raw_options =
      Application.get_all_env(:log_hog) |> Keyword.take(Keyword.keys(@configuration_schema))

    case Keyword.get(raw_options, :enable, false) do
      false -> %{enable: false}
      raw_options -> validate!(raw_options)
    end
  end

  @doc """
  See `validate/1`
  """
  @spec validate!(options :: keyword() | map()) :: config()
  def validate!(options) do
    {:ok, config} = validate(options)
    config
  end

  @doc """
  Validates configuration against the schema
  """
  @spec validate(options :: keyword() | map()) ::
          {:ok, config()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(raw_options) do
    with {:ok, validated} <- NimbleOptions.validate(raw_options, @compiled_schema) do
      config = Map.new(validated)
      client = config.api_client_module.client(config.api_key, config.public_url)
      {:ok, Map.put(config, :api_client, client)}
    end
  end
end
