defmodule Soyaki.Handler do
  @typedoc """
  * `{:continue, state :: term()}` subscribes with the socket's read_timeout, which defaults at 5000ms.
  * `{:continue, state :: term(), timeout()}` subscribes with given timeout.
  * `{:close, state}` calls `c:handle_close/2`.
  * `{:error, err, state}` calls `c:handle_error/3`.
  Timeouts callback `c:handle_timeout/2`
  """
  @type handler_result ::
          {:continue, state :: term()}
          | {:continue, state :: term(), timeout()}
          | {:close, state :: term()}
          | {:error, term(), state :: term()}

  @doc "Called during `init`, returns state."
  @callback init_state(socket :: Soyaki.Socket.t(), handler_init :: term()) :: state :: term()

  @doc "Called after the connection was accepted, returns `handler_result`"
  @callback handle_packet(packet :: binary(), socket :: Soyaki.Socket.t(), state :: term()) ::
              handler_result()

  @doc "Accepts a connection. Doesn't grab the first packet, returns `handler_result`"
  @callback handle_connection(socket :: Soyaki.Socket.t(), state :: term()) ::
              handler_result()

  @doc "Called when straight up shutting down a genserver (`:shutdown`) in terminate callback.
  Doesn't automatically close the socket."
  @callback handle_shutdown(socket :: Soyaki.Socket.t(), state :: term()) :: term()

  @doc """
  Called when shutting down the genserver with a reason, usually `:local_closed`
  from returning a `{:close, state}` continuation. Automatically closes the socket.
  """
  @callback handle_close(socket :: Soyaki.Socket.t(), state :: term()) :: term()

  @doc "Called when terminating due to `:timeout`. Automatically closes the socket."
  @callback handle_timeout(socket :: Soyaki.Socket.t(), state :: term()) :: term()

  @doc "Called when shut down for any other reason. Automatically closes the socket."
  @callback handle_error(error :: atom(), socket :: Soyaki.Socket.t(), state :: term()) ::
              term()
  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Soyaki.Handler

      use GenServer, restart: :temporary

      def init_state(_socket, handler_init), do: handler_init
      def handle_connection(_socket, state), do: {:continue, state}
      def handle_packet(_packet, _socket, state), do: {:continue, state}
      def handle_close(_socket, _state), do: :ok
      def handle_error(_error, _socket, _state), do: :ok
      def handle_shutdown(_socket, _state), do: :ok
      def handle_timeout(_socket, _state), do: :ok

      defoverridable Soyaki.Handler

      def start_link({socket, [handler_init: handler_init, genserver_opts: genserver_opts]}) do
        GenServer.start_link(__MODULE__, {socket, handler_init}, genserver_opts)
      end

      @impl GenServer
      def init({socket, handler_init} = args) do
        Process.flag(:trap_exit, true)

        Soyaki.Socket.link(socket)
        send(self(), :connection)

        state = __MODULE__.init_state(socket, handler_init)

        {:ok, {socket, state}}
      end

      def handle_info(:connection, {socket, state}) do
        __MODULE__.handle_connection(socket, state)
        |> handle_continuation(socket)
      end

      @impl GenServer
      def handle_info({msg, _, packet}, {socket, state}) when msg in [:udp] do
        __MODULE__.handle_packet(packet, socket, state)
        |> handle_continuation(socket)
      end

      def handle_info({msg, _}, {socket, state}) when msg in [:udp_closed] do
        {:stop, {:shutdown, :peer_closed}, {socket, state}}
      end

      def handle_info({msg, _, reason}, {socket, state}) when msg in [:udp_closed] do
        {:stop, reason, {socket, state}}
      end

      def handle_info(:timeout, {socket, state}) do
        {:stop, :timeout, {socket, state}}
      end

      @impl GenServer
      def terminate(:shutdown, {socket, state}) do
        __MODULE__.handle_shutdown(socket, state)
      end

      @impl GenServer
      def terminate({:shutdown, reason}, {socket, state}) do
        __MODULE__.handle_close(socket, state)

        Soyaki.Socket.close(socket, {:shutdown, reason})
      end

      @impl GenServer
      def terminate(:timeout, {socket, state}) do
        __MODULE__.handle_timeout(socket, state)

        Soyaki.Socket.close(socket, :timeout)
      end

      def terminate(reason, {socket, state}) do
        __MODULE__.handle_error(reason, socket, state)

        Soyaki.Socket.close(socket, reason)
      end

      defp handle_continuation(continuation, socket) do
        case continuation do
          {:continue, state} ->
            Soyaki.Socket.async_recv(socket)
            {:noreply, {socket, state}, socket.read_timeout}

          {:continue, state, timeout} ->
            Soyaki.Socket.async_recv(socket, timeout)
            {:noreply, {socket, state}, timeout}

          {:close, state} ->
            {:stop, {:shutdown, :local_closed}, {socket, state}}

          {:error, reason, state} ->
            {:stop, reason, {socket, state}}
        end
      end
    end
  end
end
