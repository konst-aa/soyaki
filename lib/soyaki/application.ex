defmodule Soyaki.Application do
  @moduledoc false
  use Application

  @impl true

  @spec start(any, any) :: {:ok, pid()}
  def start(_type, _args) do
    {:ok, self()}
  end
end
