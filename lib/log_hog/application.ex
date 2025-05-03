defmodule LogHog.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    with %{} = config <- LogHog.Config.read!() do
      :logger.add_handler(:log_hog, LogHog.Handler, %{config: config})
    end

    Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__)
  end
end
