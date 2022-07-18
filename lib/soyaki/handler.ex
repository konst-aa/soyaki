defmodule Soyaki.Handler do
  @type handler_result ::
          {:continue, state :: term()}
          | {:continue, state :: term(), timeout()}
          | {:close, state :: term()}
          | {:error, term(), state :: term()}

  @callback handle_packet(packet :: binary(), socket :: Soyaki.Socket.t(), state :: term()) ::
              handler_result()

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Soyaki.Handler

      use GenServer, restart: :temporary

      def handle_connection(_socket, state), do: {:continue, state}
      def handle_packet(_packet, _socket, state), do: {:continue, state}
      def handle_close(_socket, _state), do: :ok
      def handle_error(_error, _socket, _state), do: :ok
      def handle_shutdown(_socket, _state), do: :ok
      def handle_timeout(_socket, _state), do: :ok

      defoverridable(Soyaki.Handler)

      def start_link({socket, [handler_opts: handler_opts, genserver_opts: genserver_opts]}) do
        GenServer.start_link(__MODULE__, {socket, handler_opts}, genserver_opts)
      end

      @impl GenServer
      def init({socket, handler_opts}) do
        Process.flag(:trap_exit, true)

        send(self(), :connection)

        {:ok, {socket, handler_opts}}
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
        Soyaki.Socket.close(socket, {:shutdown, reason})

        __MODULE__.handle_close(socket, state)
      end

      @impl GenServer
      def terminate(:timeout, {socket, state}) do
        Soyaki.Socket.close(socket, :timeout)

        __MODULE__.handle_timeout(socket, state)
      end

      def terminate(reason, {socket, state}) do
        Soyaki.Socket.close(socket, reason)

        __MODULE__.handle_error(reason, socket, state)
      end

      def handle_continuation(continuation, socket) do
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
