# Soyaki
A udp server whose sockets provide an abstraction over :gen_udp to keep track of sessions, with no other guarantees. Semantics heavily inspired by [ThousandIsland](https://hexdocs.pm/thousand_island/ThousandIsland.html)

## Installation

Soyaki is not on hexdocs yet, so pull the dependency from git:

```elixir
def deps do
  [
    {:soyaki, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  ]
end
```

