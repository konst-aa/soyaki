defmodule Soyaki.Socket.State do
  defstruct [
    :udp_socket,
    :addr_tuple,
    :waiter,
    :timer,
    read_timeout: 4000,
    socket_opts: [],
    backlog: []
  ]

  @type t :: %__MODULE__{
          udp_socket: :gen_udp.socket(),
          addr_tuple: {:inet.ip_address(), :inet.port_number()},
          waiter: nil | pid(),
          read_timeout: integer(),
          socket_opts: [term()],
          backlog: list(),
          timer: nil | reference()
        }
end
