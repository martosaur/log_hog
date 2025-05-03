defmodule LogHog.API do
  def post_exception(%__MODULE__.Client{} = client, properties) do
    client.module.request(client.client, :post, "/i/v0/e",
      json: %{
        event: "$exception",
        properties: properties
      }
    )
  end
end
