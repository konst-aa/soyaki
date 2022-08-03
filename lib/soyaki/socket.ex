defmodule Soyaki.Socket do
  @moduledoc """
  A struct that keeps track of options, and the underlying socket pid. Provides
  functionality to link/unlink, send, receive, and close. Banged versions might be a thing one day.
  """

  defstruct [:socket_pid, :socket_options, read_timeout: 5000]
  use GenServer

  alias Soyaki.Socket.State

  @typedoc "A reference to a socket along with some info."
  @type t :: %__MODULE__{
          socket_pid: pid(),
          socket_options: []
        }
  @type options :: []

  # API

  @doc false
  @spec new(pid(), options()) :: t()
  def new(socket_pid, socket_options) do
    struct(__MODULE__, Map.merge(%{socket_pid: socket_pid}, Map.new(socket_options)))
  end

  @doc """
  Links a socket to the calling process.
  """
  @spec link(t()) :: :ok
  def link(%__MODULE__{socket_pid: socket_pid}) do
    Process.link(socket_pid)
    :ok
  end

  @doc """
  Uninks a socket from the calling process.
  """
  @spec unlink(t()) :: :ok
  def unlink(%__MODULE__{socket_pid: socket_pid}) do
    Process.unlink(socket_pid)
    :ok
  end

  @doc """
  Sends a udp packet to the connected ip and port.
  """
  def send(%{socket_pid: pid}, packet) do
    GenServer.cast(pid, {:send, packet})
  end

  @doc """
  Listens for a packet to arrive in the socket. Blocks the calling process.
  """
  @spec recv(__MODULE__.t(), nil | integer()) :: {:ok, binary()} | {:error, :timeout}
  def recv(%{socket_pid: pid}, timeout \\ nil) do
    GenServer.cast(pid, {:recv, self(), timeout})

    receive do
      :timeout -> {:error, :timeout}
      {:udp_closed, _} -> {:error, :udp_closed}
      {:udp, _, packet} -> {:ok, packet}
    end
  end

  @doc """
  Subscribes the calling process to the next packet to arrive in the socket. Can send one of 3 messages:
  ```elixir
  :timeout
  {:udp_closed, nil}
  {:udp, nil, packet}
  ```
  """
  @spec async_recv(__MODULE__.t(), nil | integer()) :: :ok
  def async_recv(%{socket_pid: pid}, timeout \\ nil) do
    GenServer.cast(pid, {:recv, self(), timeout})
  end

  @doc """
  Closes the socket. If specified, a final packet would be sent. Bold of you to expect for it to arrive, though.
  """
  @spec close(__MODULE__.t(), atom(), nil | binary()) :: :ok
  def close(%{socket_pid: pid}, reason \\ nil, lastpacket \\ nil) do
    GenServer.cast(pid, {:close, reason, lastpacket})
  end

  # GenServer stuff
  def start_link({{_, _, host, port, _}, _options} = args) do
    GenServer.start_link(__MODULE__, args, name: Soyaki.Socket.Registry.via_tuple(host, port))
  end

  @impl true
  def init({{:udp, udp_socket, host, port, packet}, socket_options}) do
    Process.flag(:trap_exit, true)

    {:ok,
     %State{
       udp_socket: udp_socket,
       addr_tuple: {host, port},
       socket_options: socket_options,
       backlog: [packet]
     }}
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
    Kernel.send(from, {:error, :not_waiter})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:recv, from, _timeout}, %State{backlog: [packet | tail]} = state) do
    Kernel.send(from, {:udp, nil, packet})
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
    Kernel.send(waiter, {:udp, nil, packet})
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
    Kernel.send(waiter, :timeout)
    {:noreply, Map.put(state, :waiter, nil)}
  end

  def handle_info({:EXIT, _, reason}, state) do
    {:stop, reason, state}
  end

  @impl true
  def terminate({:shutdown, {:close, _}}, %State{addr_tuple: _addr_tuple, waiter: waiter}) do
    if waiter do
      Kernel.send(waiter, {:udp_closed, nil})
    end

    :ok
  end

  def terminate(_, _) do
    :ok
  end
end
