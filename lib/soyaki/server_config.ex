defmodule Soyaki.ServerConfig do
  defstruct [
    :handler_module,
    :announce,
    port: 40000,
    handler_init: [],
    genserver_opts: [],
    socket_opts: []
  ]

  @type t :: %__MODULE__{
          port: integer(),
          handler_module: module(),
          handler_init: any(),
          genserver_opts: [] | [term()]
        }

  @spec new([term()]) :: __MODULE__.t() | no_return()
  def new(terms) do
    config = Kernel.struct(__MODULE__, terms)

    if Map.get(config, :handler_module) == nil do
      raise "Can't start server: no handler module provided."
    end

    config
  end
end
