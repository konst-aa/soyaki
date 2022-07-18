defmodule Soyaki.Socket.Registry do
  def start_args() do
    [keys: :unique, name: __MODULE__]
  end

  def via_tuple(ip, port) do
    {:via, Registry, {__MODULE__, {ip, port}}}
  end
end
