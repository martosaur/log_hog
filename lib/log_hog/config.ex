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
      doc: "`https://us.i.posthog.com` for US cloud or `https://eu.i.posthog.com` for EU cloud"
    ],
    api_key: [
      type: :string,
      required: true,
      doc: """
      Your PostHog Project API key. Find it in your project's settings under Project ID section
      """
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
    ],
    in_app_otp_apps: [
      type: {:list, :atom},
      default: [],
      doc:
        "List of OTP app names of your applications. Stacktrace entries that belong to these apps will be marked as \"in_app\""
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
  @spec read!() :: config()
  def read!() do
    raw_options =
      Application.get_all_env(:log_hog) |> Keyword.take(Keyword.keys(@configuration_schema))

    case Keyword.get(raw_options, :enable) do
      false -> %{enable: false}
      _ -> validate!(raw_options)
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

      final_config =
        config
        |> Map.put(:api_client, client)
        |> Map.put(
          :in_app_modules,
          config.in_app_otp_apps |> Enum.flat_map(&Application.spec(&1, :modules)) |> MapSet.new()
        )
        |> Map.put(:global_context, %{
          "$lib": "LogHog",
          "$lib_version": Application.spec(:log_hog, :vsn) |> to_string()
        })

      {:ok, final_config}
    end
  end
end
