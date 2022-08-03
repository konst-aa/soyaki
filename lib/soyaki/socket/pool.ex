defmodule Soyaki.Socket.Pool do
  use GenServer

  defstruct [:handler_module]

  @type t :: %__MODULE__{
          handler_module: module()
        }

  alias Soyaki.Socket

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(config) do
    Process.flag(:trap_exit, true)
    {:ok, config}
  end

  def incoming_packet(msg) do
    GenServer.cast(__MODULE__, {:incoming_packet, msg})
  end

  @impl true
  def handle_cast(
        {:incoming_packet, {:udp, _udp_socket, host, port, packet} = msg},
        %{
          handler_module: handler_module,
          socket_opts: socket_opts,
          handler_init: handler_init,
          genserver_opts: genserver_opts
        } = state
      ) do
    case Registry.lookup(Soyaki.Socket.Registry, {host, port}) do
      [{pid, _}] ->
        GenServer.cast(pid, {:incoming_packet, packet})

      [] ->
        {:ok, socket_pid} = Socket.start_link({msg, socket_opts})

        handler_module.start_link(
          {Socket.new(socket_pid, socket_opts),
           [handler_init: handler_init, genserver_opts: genserver_opts]}
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(info, state) do
    IO.inspect(info)
    {:noreply, state}
  end
end
