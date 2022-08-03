defmodule Soyaki.Listener do
  @moduledoc false

  use GenServer

  @spec start_link(integer()) :: :ok
  def start_link(port) do
    GenServer.start_link(__MODULE__, port)
  end

  @impl true
  def init(%{port: port, announce: announce} = _args) do
    {:ok, socket} = :gen_udp.open(port, active: true, ip: {0, 0, 0, 0})

    if announce do
      {:ok, port} = :inet.port(socket)
      IO.puts("Soyaki up at port :#{port}")
    end

    {:ok, socket}
  end

  @impl true
  def handle_call(:gimmesocket, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:udp, _socket, _host, _port, _packet} = msg, state) do
    Soyaki.Socket.Pool.incoming_packet(msg)
    {:noreply, state}
  end
end
