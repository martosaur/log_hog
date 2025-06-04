defmodule LogHog.API.Client do
  @moduledoc """
  Behaviour and the default implementation of a PostHog API Client. Uses `Req`.
  """
  @behaviour __MODULE__

  defstruct [:client, :module]

  @type t() :: %__MODULE__{
          client: client(),
          module: atom()
        }
  @type client() :: any()
  @type response() :: {:ok, %{status: non_neg_integer(), body: any()}} | {:error, Exception.t()}

  @callback client(api_key :: String.t(), cloud :: String.t()) :: t()
  @callback request(client :: client(), method :: atom(), url :: String.t(), opts :: keyword()) ::
              response()

  @impl __MODULE__
  def client(api_key, public_url) do
    client =
      Req.new(base_url: public_url)
      |> Req.Request.put_private(:api_key, api_key)

    %__MODULE__{client: client, module: __MODULE__}
  end

  @impl __MODULE__
  def request(client, method, url, opts) do
    client
    |> Req.merge(
      method: method,
      url: url
    )
    |> Req.merge(opts)
    |> then(fn req ->
      req
      |> Req.Request.fetch_option(:json)
      |> case do
        {:ok, json} ->
          api_key = Req.Request.get_private(req, :api_key)
          Req.merge(req, json: Map.put_new(json, :api_key, api_key))

        :error ->
          req
      end
    end)
    |> Req.request()
  end
end
