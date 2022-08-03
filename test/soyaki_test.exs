defmodule Keeper do
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, & &1)
  end

  def push(val) do
    Agent.update(__MODULE__, &(&1 ++ [val]))
  end
end

defmodule SoyakiTest do
  use ExUnit.Case
  doctest Soyaki

  defmodule Echoer do
    use Soyaki.Handler
    alias Soyaki.Socket

    @impl Soyaki.Handler
    def handle_connection(socket, state) do
      {:ok, packet} = Socket.recv(socket)
      Keeper.push(List.first(state))
      Keeper.push(packet)
      Process.exit(Map.get(socket, :socket_pid), :normal)
      {:continue, state}
    end

    @impl Soyaki.Handler
    def handle_packet(packet, _, state) do
      Keeper.push(packet)
      {:continue, state}
    end

    @impl Soyaki.Handler
    def handle_info(
          {:EXIT, socket_pid, reason},
          {%Socket{socket_pid: socket_pid}, _} = state_tuple
        ) do
      {:stop, reason, state_tuple}
    end
  end

  test "receives stuff" do
    Keeper.start_link([])

    {:ok, pid} = Soyaki.start_link(port: 42900, handler_module: Echoer, handler_init: ["init"])

    {:ok, socket} = :gen_udp.open(42420, ip: {0, 0, 0, 0})
    :gen_udp.send(socket, {{0, 0, 0, 0}, 42900}, "hello world!")
    :gen_udp.send(socket, {{0, 0, 0, 0}, 42900}, "not world!")
    :timer.sleep(3000)
    assert ["init", 'hello world!'] == Keeper.get()
  end
end
