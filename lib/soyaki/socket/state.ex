defmodule Soyaki.Socket.State do
  @moduledoc "The state struct for the socket GenServer"
  defstruct [
    :udp_socket,
    :addr_tuple,
    :waiter,
    :timer,
    read_timeout: 5000,
    socket_options: [],
    backlog: []
  ]

  @type t :: %__MODULE__{
          udp_socket: :gen_udp.socket(),
          addr_tuple: {:inet.ip_address(), :inet.port_number()},
          waiter: nil | pid(),
          read_timeout: integer(),
          socket_options: Soyaki.Socket.options(),
          backlog: list(),
          timer: nil | reference()
        }
end
