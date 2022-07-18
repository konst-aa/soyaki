defmodule Soyaki do
  @type options :: [
          handler_module: module(),
          announce: nil | true,
          handler_options: term(),
          port: :inet.port_number(),
          num_acceptors: pos_integer(),
          timeout: integer()
        ]

  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @spec start_link(options()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    opts
    |> Soyaki.ServerConfig.new()
    |> Soyaki.Server.start_link()
  end
end
