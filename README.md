# Zmex

<!-- @moduledoc Zmex -->

_**IF by NIF:**
Call a Rust Z-Machine from Elixir and run classic text-adventure games
(Inform v4, v5, v8)_

## Installation

Add `zmex` to your list of dependencies in `mix.exs`, then run `mix deps.get`:

```elixir
def deps do
  [
    {:zmex, "~> 0.1.0"}
  ]
end
```

## Usage

The easiest way to understand how to use `zmex` to run Z-Machine games within your
Elixir programs is to experiment with the library in Elixir's REPL, `iex`:

```elixir
TODO
```

A full reference example Elixir CLI program which uses `zmex` to run any Z-Machine
game is included within the `zmex_cli` directory at the top level of this repository:
https://github.com/e2enterprises/zmex/blob/main/zmex_cli/lib/zmex_cli.ex

To run this CLI program, simply clone the repository:
```
git clone git@github.com:e2enterprises/zmex.git
```
then run
```
cd zmex
mix play advent.z3  # Play the classic https://dwheeler.com/adventure/
# Run following command to view other story files you may select from:
# ls native/encrusted_nif/encrusted-heart/tests/
```

## Implementation Notes

TODO

<!-- /@moduledoc Zmex -->

## License

MIT

