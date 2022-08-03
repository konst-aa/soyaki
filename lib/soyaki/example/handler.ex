defmodule Echo do
  @moduledoc false

  use Soyaki.Handler

  @impl Soyaki.Handler
  def handle_packet(packet, _socket, state) do
    IO.inspect(packet)
    {:continue, state}
  end
end
