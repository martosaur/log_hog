defmodule LogHog.Context do
  @moduledoc """
  Context is Logger metadata purposefully set to be exported regardless of `LogHog.Config`'s `metadata` setting.
  """

  @type t() :: map()

  @logger_metadata_key :__loghog__

  @doc """
  Set context for the current process.
  """
  @spec set(t()) :: :ok
  def set(new_context) do
    context =
      case :logger.get_process_metadata() do
        %{@logger_metadata_key => existing} -> Map.merge(existing, new_context)
        _ -> new_context
      end

    :logger.update_process_metadata(%{@logger_metadata_key => context})
  end

  @doc """
  Obtain the context of the current process.
  """
  @spec get() :: t()
  def get() do
    case :logger.get_process_metadata() do
      %{@logger_metadata_key => config} -> config
      %{} -> %{}
      :undefined -> %{}
    end
  end
end
