defmodule Pigeon do
  @moduledoc """
  HTTP2-compliant wrapper for sending iOS and Android push notifications.
  """

  @doc false
  def start_connection(state) do
    opts = [restart: :temporary, id: :erlang.make_ref()]
    spec = Supervisor.child_spec({Pigeon.Connection, state}, opts)
    Supervisor.start_child(:pigeon, spec)
  end

  def debug_log?, do: Application.get_env(:pigeon, :debug_log, false)
end
