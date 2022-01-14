defmodule Pigeon.Supervisor do
  @moduledoc """
  HTTP2-compliant wrapper for sending iOS and Android push notifications.
  """

  use Supervisor

  require Logger

  alias Pigeon.{ADM, APNS, FCM}
  alias Pigeon.Http2.Client

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, nil, name: :pigeon)
  end

  @impl true
  def init(_args) do
    client_spec = Client.default().child_spec()
    children = [client_spec | workers()]
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp workers do
    [
      adm_workers(),
      apns_workers(),
      fcm_workers(),
      env_workers(),
      apns_token_agent(),
      task_supervisors()
    ]
    |> List.flatten()
  end

  defp apns_token_agent do
    [{APNS.Token, %{}}]
  end

  defp task_supervisors do
    [{Task.Supervisor, name: Pigeon.Tasks}]
  end

  defp env_workers do
    case Application.get_env(:pigeon, :workers) do
      nil ->
        []

      workers ->
        Enum.flat_map(workers, fn {mod, fun} ->
          mod
          |> apply(fun, [])
          |> List.wrap()
          |> Enum.map(&worker/1)
          |> Enum.filter(& &1)
        end)
    end
  end

  defp worker(%ADM.Config{} = config) do
    Supervisor.child_spec({ADM.Worker, config}, id: config.name, restart: :temporary)
  end

  defp worker(config) do
    Supervisor.child_spec({Pigeon.Worker, config}, id: config.name, restart: :temporary)
  end

  defp adm_workers do
    workers_for(:adm, &ADM.Config.new/1, Pigeon.ADM.Worker)
  end

  defp apns_workers do
    workers_for(:apns, &APNS.ConfigParser.parse/1, Pigeon.Worker)
  end

  defp fcm_workers do
    workers_for(:fcm, &FCM.Config.new/1, Pigeon.Worker)
  end

  defp workers_for(name, config_fn, mod) do
    case Application.get_env(:pigeon, name) do
      nil ->
        []

      workers ->
        Enum.map(workers, fn {worker_name, _config} ->
          config = config_fn.(worker_name)
          Supervisor.child_spec({mod, config}, id: config.name, restart: :temporary)
        end)
    end
  end
end
