defmodule SoyakiTest do
  use ExUnit.Case
  doctest Soyaki

  test "receives stuff" do
    {:ok, socket} = :gen_udp.open(42420, ip: {0, 0, 0, 0})
    :gen_udp.send(socket, {{0, 0, 0, 0}, 42900}, "hello world!")

    :timer.sleep(3000)
  end
end
