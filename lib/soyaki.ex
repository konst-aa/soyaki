defmodule Soyaki do
  @moduledoc """
    Soyaki is a thin abstraction over erlang's `:gen_udp` sockets, providing the notion of sessions.
    Semantics heavily inspired by [ThousandIsland](https://hexdocs.pm/thousand_island/ThousandIsland.html).

  Soyaki is implemented as a supervision tree, but currently uses named processes,
  so you could only run one instance. Applications interact with the sockets primarily through
  the `Soyaki.Handler` behavior.

  ## Handlers

  The `Soyaki.Handler` behavior exists to pass sockets up to the application level.
  Internally, it's a `GenServer` whose state tuple consists of `{socket, state}`
  (Just a bit of info for anyone who wants to add on to `handle_info` callbacks).
  Handlers link to the socket on initialization. Here is an example handler that
  inspects an incoming packet.
  ```elixir
  defmodule Echo do
    use  Soyaki.Handler

    @impl Soyaki.Handler
    def handle_packet(packet, socket, state) do
      IO.inspect(packet)
      {:continue, state}
    end
  end
  {:ok, pid} = Soyaki.start_link(port: 1234, handler_module: Echo)
  ```
  For more information, including other callbacks, please consult the `Soyaki.Handler` documentation.

  ## Starting a Soyaki Server

  A typical use of `Soyaki` might look like the following:

  ```elixir
  defmodule MyApp.Supervisor do

    # ... other Supervisor boilerplate

    def init(config) do
      children = [
      # ... other children as dictated by your app
      {Soyaki, port: 1234, handler_module: MyApp.ConnectionHandler}
      ]
      Supervisor.init(children, strategy: :one_for_one)
    end
  end
  ```

  ## Shutdowns and Crashes
  Shutdowns are probably fine. For crashes, sockets trap exits and gracefully shut down when they get
  exit signals from linked processes. `Soyaki.Handler` doesn't do that by default, but here's an example of
  a `handle_info` callback that implements this:
  ```elixir
  @impl Soyaki,Handler
  def handle_info(
    {:EXIT, socket_pid, reason},
    {%Socket{socket_pid: socket_pid},  _}  = state_tuple
    ) do
    {:stop, reason, state_tuple}
  end
  ```

  ## Internals & Sockets
  `Soyaki` keeps a registry mapping `{host_addr, port}` tuples to socket pids.
  It routes packets arriving in the `:gen_udp` socket to its own sockets, which are asynchronously
  listened to by the handlers. A "connection" occurs when a packet arrives from an address that the
  registry doesn't have a socket for.

  ## Scaling & Stress Testing
  TBD
  """

  @type options :: [
          handler_module: module(),
          announce: nil | true,
          handler_options: Soyaki.Handler.options(),
          socket_options: Soyaki.Socket.options(),
          port: :inet.port_number(),
          timeout: integer()
        ]

  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Starts a `Soyaki` instance with the given options. Returns a pid
  that can be used to further manipulate the server via other functions defined on
  this module in the case of success, or an error tuple describing the reason the
  server was unable to start in the case of failure.
  """
  @spec start_link(options()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    opts
    |> Soyaki.ServerConfig.new()
    |> Soyaki.Server.start_link()
  end

  @doc """
  Synchronously stops the given server, waiting up to the given number of milliseconds
  for existing connections to finish up. Immediately upon calling this function,
  the server stops listening for new connections, and then proceeds to wait until
  either all existing connections have completed or the specified timeout has
  elapsed.
  """
  @spec stop(pid(), timeout()) :: :ok
  def stop(pid, connection_wait \\ 15_000) do
    Supervisor.stop(pid, :normal, connection_wait)
  end
end
