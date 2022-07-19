defmodule Soyaki.Application do
  use Application

  @impl true

  @spec start(any, any) :: {:ok, pid()}
  def start(_type, _args) do
    {:ok, self()}
  end
end
