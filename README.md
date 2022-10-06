# Soyaki why would you ever use this? Just open a udp socket whenever necessary, and communicate over tcp

A udp server whose sockets provide an abstraction over :gen_udp to keep track of sessions, with no other guarantees. Semantics heavily inspired by [ThousandIsland](https://hexdocs.pm/thousand_island/ThousandIsland.html).

pls open issues for typos or literally anything

## Options are broken and undocumented

Can't be bothered rn, might fix one day:

- [ ] CI for fixing bugs **THIS IS ACTUALLY IMPORTANT**
- [ ] don't use named processes **THIS IS ACTUALLY IMPORTANT**
- [ ] genserver_opts not provided to handler
- [ ] socket opts never fully updated in `new`, nor passed around properly in pool.
- [ ] tests
- [ ] more docs

## Installation

On hexdocs, but I wouldn't say it's worthy.

```elixir
def deps do
  [
    {:soyaki, "~> 1.0.0"}
  ]
end
```
