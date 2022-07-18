defmodule Soyaki.Example.Handler do
  use Soyaki.Handler

  @impl Soyaki.Handler
  def handle_packet(packet, socket, state) do
    IO.inspect(packet)
    {:continue, state}
  end
end
