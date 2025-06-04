defmodule LogHog.API do
  @moduledoc false
  def post_batch(%__MODULE__.Client{} = client, batch) do
    client.module.request(client.client, :post, "/batch", json: %{batch: batch})
  end
end
