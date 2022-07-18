defmodule Soyaki.Socket do
  defstruct [:socket_pid, read_timeout: 5000]
  use GenServer

  alias Soyaki.Socket.State

  @type t :: %__MODULE__{
          socket_pid: pid()
        }

  @type opts :: %{}

  # API

  def new(socket_pid, socket_opts) do
    struct(__MODULE__, Map.merge(%{socket_pid: socket_pid}, Map.new(socket_opts)))
  end

  def send(%{socket_pid: pid}, packet) do
    GenServer.cast(pid, {:send, packet})
  end

  @spec recv(__MODULE__.t(), nil | integer()) :: {:ok, binary()} | {:error, :timeout}
  def recv(%{socket_pid: pid}, timeout \\ nil) do
    GenServer.cast(pid, {:recv, self(), timeout})

    receive do
      :timeout -> {:error, :timeout}
      {:udp_closed, _} -> {:error, :udp_closed}
      {:udp, _, packet} -> {:ok, packet}
    end
  end

  @spec async_recv(__MODULE__.t(), nil | integer()) :: :ok
  def async_recv(%{socket_pid: pid}, timeout \\ nil) do
    GenServer.cast(pid, {:recv, self(), timeout})
  end

  @spec close(__MODULE__.t(), atom(), nil | binary()) :: :ok
  def close(%{socket_pid: pid}, reason \\ nil, lastpacket \\ nil) do
    GenServer.cast(pid, {:close, reason, lastpacket})
  end

  # GenServer stuff
  def start_link({{_, _, host, port, _}, _opts} = args) do
    GenServer.start_link(__MODULE__, args, name: Soyaki.Socket.Registry.via_tuple(host, port))
  end

  @impl true
  def init({{:udp, udp_socket, host, port, packet}, socket_opts}) do
    Process.flag(:trap_exit, true)
    GenServer.cast(self(), {:incoming_packet, packet})
    {:ok, %State{udp_socket: udp_socket, addr_tuple: {host, port}, socket_opts: socket_opts}}
  end

  def handle_cast({:recv, from, _timeout}, %State{waiter: from} = state) do
    # ignores for now, maybe introduce a waiter queue?
    {:noreply, state}
  end

  def handle_cast(
        {:recv, from, _timeout},
        %State{waiter: waiter} = state
      )
      when waiter != from and waiter do
    Process.send(from, {:error, :not_waiter}, [])
    {:noreply, state}
  end

  @impl true
  def handle_cast({:recv, from, _timeout}, %State{backlog: [packet | tail]} = state) do
    Process.send(from, {:udp, nil, packet}, [])
    {:noreply, Map.put(state, :backlog, tail)}
  end

  def handle_cast({:recv, from, timeout}, %State{backlog: [], read_timeout: read_timeout} = state) do
    timer =
      if timeout != :infinity || read_timeout != :infinity do
        Process.send_after(self(), :timeout, timeout || read_timeout)
      else
        nil
      end

    {:noreply, Map.put(state, :waiter, from) |> Map.put(:timer, timer)}
  end

  def handle_cast({:incoming_packet, packet}, %State{backlog: backlog, waiter: nil} = state) do
    # linear time, how screwed am I?
    backlog = backlog ++ [packet]
    {:noreply, Map.put(state, :backlog, backlog)}
  end

  def handle_cast({:incoming_packet, packet}, %State{waiter: waiter, timer: timer} = state)
      when is_pid(waiter) do
    Process.cancel_timer(timer)
    Process.send(waiter, {:udp, nil, packet}, [])
    {:noreply, Map.put(state, :waiter, nil)}
  end

  def handle_cast({:send, packet}, %State{udp_socket: udp_socket, addr_tuple: addr_tuple} = state) do
    :gen_udp.send(udp_socket, addr_tuple, packet)
    {:noreply, state}
  end

  def handle_cast(
        {:close, reason, lastpacket},
        %State{udp_socket: udp_socket, addr_tuple: addr_tuple} = state
      ) do
    if lastpacket do
      :gen_udp.send(udp_socket, addr_tuple, lastpacket)
    end

    {:stop, {:shutdown, {:close, reason}}, state}
  end

  @impl true
  def handle_info(:timeout, %{waiter: waiter} = state) when is_pid(waiter) do
    Process.send(waiter, :timeout, [])
    {:noreply, Map.put(state, :waiter, nil)}
  end

  @impl true
  def terminate({:shutdown, {:close, _}}, %State{addr_tuple: addr_tuple, waiter: waiter}) do
    if waiter do
      Process.send(waiter, {:udp_closed, nil}, [])
    end

    :ok
  end

  def terminate(_, _) do
    :ok
  end
end
