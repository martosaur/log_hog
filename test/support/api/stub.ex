defmodule LogHog.API.Stub do
  @behaviour LogHog.API.Client

  @impl LogHog.API.Client
  def client(_api_key, _public_url) do
    %LogHog.API.Client{client: :stub_client, module: LogHog.API.Mock}
  end

  @impl LogHog.API.Client
  def request(_client, :post, "/i/v0/e", _opts) do
    {:ok, %{status: 200, body: %{"status" => "Ok"}}}
  end
end
