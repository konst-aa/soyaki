defmodule Soyaki.Application do
  use Application

  @impl true

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    children = [
      {Soyaki, port: 42900, announce: true, handler_module: Soyaki.Example.Handler}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
