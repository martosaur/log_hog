defmodule LogHog.API do
  def post_exception(%__MODULE__.Client{} = client, properties) do
    client.module.request(client.client, :post, "/i/v0/e",
      json: %{
        event: "$exception",
        properties: properties
      }
    )
  end

  def post_batch(%__MODULE__.Client{} = client, batch) do
    client.module.request(client.client, :post, "/batch", json: %{batch: batch})
  end
end
