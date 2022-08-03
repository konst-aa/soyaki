# Soyaki
A udp server whose sockets provide an abstraction over :gen_udp to keep track of sessions, with no other guarantees. Semantics heavily inspired by [ThousandIsland](https://hexdocs.pm/thousand_island/ThousandIsland.html)

## Options are broken and undocumented.
Can't be bothered rn, might fix one day:
- [ ] genserver_opts not provided to handler
- [ ] socket opts never fully updated in `new`, not passed around properly in pool.

## Installation

Soyaki is a long way from hexdocs, so pull the dependency from git:

```elixir
def deps do
  [
    {:soyaki, git: "https://github.com/konstantin-aa/soyaki.git"}
  ]
end
```

