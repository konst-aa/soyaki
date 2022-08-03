defmodule Soyaki.Server do
  @moduledoc false

  use Supervisor

  def start_link(%Soyaki.ServerConfig{} = config) do
    Supervisor.start_link(__MODULE__, config)
  end

  def init(config) do
    children = [
      {Soyaki.Listener, config},
      {Soyaki.Socket.Pool, config},
      {Registry, Soyaki.Socket.Registry.start_args()}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
