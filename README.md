# Zmex

<!-- @moduledoc Zmex -->

_**IF by NIF:**
Call [a Rust Z-Machine](https://github.com/bkirwi/folly/tree/master/encrusted-heart)
from Elixir and run classic text-adventure games
(Inform v3, v4, v5, v8)_

## Installation

Add `{:zmex, "~> 0.1.1"}` to your list of dependencies in `mix.exs`, then run `mix deps.get`.

## Reference Sheet

```elixir
Zmex.new_game/1 (story) -> {save, output, seed}
Zmex.new_game/2 (story, input) -> {save, output, seed}
Zmex.new_game/3 (story, input, opts) -> {save, output, seed, diagnostics}
Zmex.continue/3 (story, save, input) -> {save, output, seed}
Zmex.continue/4 (story, save, input, opts) -> {save, output, seed, diagnostics}

Parameters
----------
story # · · · · · · · · · · · · · · non-empty binary
save  # · · · · · · · · · · · · · · non-empty binary
input # · · · · · · · · · · · · · · string or non-empty list of strings
opts \\ []  # · · · · · · · · · · · optional keyword list of options
   L seed: {i32, i32, i32, i32} # · random seed for deterministic story behavior
   L step_through_blank: true   # · auto-step through steps in story with no output
   L diagnostics: true  # · · · · · return diagnostic info map as 3rd tuple value
   L dirty_nifs: []     # · · · · · list of atoms corresponding with NIF functions
                                # · to be marked with schedule="DirtyCpu" for Rustler
Return Tuples
-------------
diagnostics: false ->
  {save: binary, output: str, seed: {i32, i32, i32, i32} }
diagnostics: true ->
  {save: binary, output: str, seed: {i32 x 4}, diagostics: %{nif_duration: i32} }
  # Note: NIF diagnostic timing durations are always returned in milliseconds.
```

## Usage

The easiest way to understand how to use `zmex` to run Z-Machine games within your
Elixir programs is to experiment with the library in Elixir's REPL, `iex`:

```elixir
$ iex -S mix  # run from root directory of project where you installed Zmex

iex[1]> story = File.read!("deps/zmex/native/encrusted_nif/encrusted-heart/tests/advent.z3")
# `story` is binary data read from any Inform file (Inform v3, v4, v5, v8 supported)

iex[2]> {save, output, seed} = Zmex.new_game(story)

{<<70, 79, 82, 77, 0, 0, 0, 176, 73, 70, 90, 83, 73, 70, 104, ... 255, 0, 255>>,
 "Welcome to Adventure! Do you need instructions? (y/n) >(Please type y or n)",
 {-236729853, 1784278710, 2078833209, 1610991913}}
```

You've just started a new game of [Adventure](https://dwheeler.com/adventure/).
The raw "UI" isn't as cozy a gameplay experience as we'd usually like, but it
provides everything you need to build your own Elixir applications around the
"[Encrusted Heart](https://github.com/bkirwi/folly/tree/master/encrusted-heart)"
Z-machine implementation.

These three values were returned from `Zmex.new_game`
- **`save`**: The call to `Zmex.new_game` produced binary-data representation of the
  current internal state of the Z-machine. Zmex is entirely stateless on its
  own; you choose what to do with this save data. Keep it in memory, write to
  a file, whatever you want. It just needs to be passed with the next call
  to continue the game.
- **`output`**: This is a string containing the response from the game. Usually it's
  responding to user input, but in the case of `Zmex.new_game` input can
  be blank and output generally contains the "title-page" or "intro" text
  of the game being played. Only way to know for sure is to play the game!
- **`seed`**: Every play-through of a Z-machine game continually passes a seed value
  to the Z-machine's internal random number generator (RNG). Generally you'll want
  to hang on to the seed produced during `Zmex.new_game`
  and pass that same seed with every subsequent `Zmex.continue` call. Changing seed
  midway during a game won't cause egregious errors, but has the potential to cause
  subtler issues; see
  [The Z-machine, And How To Emulate It (PDF)](https://mirror.ifarchive.org/if-archive/infocom/interpreters/specification/zspec02/zmach06e.pdf)
  for more context, specifically section **_2.6. Random number generator_**.
  Ultimately, how you handle RNG seeds is up to you and your application's specific
  needs; Zmex simply aims to make this aspect of Z-machine operation transparent and
  straightforward to work with.
  - Per the Z-machine impl. Zmex uses, the seed is always a 4-tuple of uniformly
    random **32-bit _signed_ integers** (though they're converted to unsigned
    ints when passed to Z-machine during NIF execution).

```elixir
iex[3]> {save, output, seed} = Zmex.continue(story, save, "n", seed: seed)

{{<<70, 79, 82, 77, 0, 0, 1, 8, 73, 70, 90, 83, 73, 70, 104, ... 255, 0, 255>>,
 "ADVENTURE\nA Modern Classic\nBased on Adventure by Willie Crowther and Don Woods (1977)\nAnd prior adaptations by David M. Baggett (1993), Graham Nelson (1994), and others\nAdapted once more by Jesse McGrew (2015)\nRelease 1 / Serial number 151001 / ZILF 0.7 lib J3\n\nAt End Of Road\nYou are standing at the end of a road before a small brick building. Around you is a forest. A small stream flows out of the building and down a gully.",
 {-236729853, 1784278710, 2078833209, 1610991913}}
```

It should be reasonably clear where this is going:

```elixir
iex[4]> {save, output, seed} = Zmex.continue(story, save, "north", seed: seed)

{<<70, 79, 82, 77, 0, 0, 1, 52, 73, 70, 90, 83, 73, 70, 104, ... 255, 0, 255>>,
 "In Forest\nYou are in open forest near both a valley and a road.",
 {-236729853, 1784278710, 2078833209, 1610991913}}
```

## Example Application

A full reference example Elixir CLI program which uses `zmex` to run any Z-Machine
game is included within the `zmex_cli` directory at the top level of this repository:
https://github.com/e2enterprises/zmex/blob/main/zmex_cli/lib/zmex_cli.ex

To run this CLI program, simply clone the repository:
```sh
git clone git@github.com:e2enterprises/zmex.git
```
then run
```sh
cd zmex/zmex_cli
mix loop advent.z3  # Play the classic: https://rickadams.org/adventure/
# Run following command to view other story files you may select from:
# ls native/encrusted_nif/encrusted-heart/tests/
```
The above command puts the CLI program into a simple input<>response loop. To help
the program serve as blueprint, it's been intentionally pared-down as far as possible;
basic quality-of-life features such as the following are left as an exercise
to the reader:
- left/right arrow keys to navigate around and edit text on the prompt line
- up/down arrow keys to browse and re-enter previous inputs
- any sort of multi-line input
- any way to manually save or load a game, or keep multiple saves
- any way to quit, other then pressing `CTRL+C` twice in a row
- many other things that would probably be fun to implement!

If you prefer to run a single game step at a time instead of looping, use the `step`
command instead:

```sh
mix step advent.z3
```
Both commands will read from and write to the same save file, meaning they'll both
interact with the same game session. To restart the game, you can either delete this
game save file or run
```sh
mix step --reset advent.z3
# or
mix loop --reset advent.z3
```
The game save file for this example program is always stored adjacent to the story
file, which in the examples above resides at
```sh
zmex/native/encrusted_nif/encrusted-heart/tests/advent.z3
```
The save file the example program produces is always called
```sh
zmex/native/encrusted_nif/encrusted-heart/tests/advent_save.qz
# .qz refers to the "Quetzal" save format: https://www.ifwiki.org/Quetzal
```
which means there can only be a single session of each game running, with a single
save point, at any given time. Any real-world program beyond this simple example
will likely want to provide an intuitive system for managing any number of session
and saves for each game, but this is fully outside the purview of Zmex. This library
is intended to provide you with direct access to the binary data reprensenting game
saves, and even the act of writing to file or persisting somewhere else is left as
a choice you are able to make. In the case of the example `zmex_cli`, it simply
writes the data directly to a file.


## Implementation Notes

As evidenced by example above, Zmex is entirely stateless. Every function call
receives input data\
(`story`, `save`, `input`, `seed`) and returns output data
(`save`, `output`, `seed`) but the caller must decide what is done with that data;
whether it's just held in memory, or persisted to database or disk.

A natural critique of this approach is that starting up an entire Z-machine instance
fresh during every step of gameplay seems wasteful. Indeed, interacting with a
persistently-running Z-machine instance would likely be a more optimal use of
resources, but it would come at a cost: simplicity, and natural integration with
OTP and the BEAM, Elixir's (and Erlang's) much-beloved runtime. BEAM and state are
oil and water; what goes with the flow is work that can be split into small
pieces and spread across many independent workers. Thanks to the raw performance of
Rust, and the elegant bridge to it provided by
[Rustler](https://github.com/rusterlium/rustler), working with a Z-machine in a way
that fits this ideal interaction model is now possible in Elixir.

Great pains have been taken to ensure that all NIFs called by Zmex return in under
1ms, a threshold that allows them to avoid being scheduled as
["dirty"](https://www.erlang.org/doc/apps/erts/erl_nif.html#dirty_nifs)
and incur performance penalties. While developing applications with Zmex,
please make your own performance measurements by passing `diagnostics: true` to any
Zmex call, which will provide detailed per-NIF timing information. It's impossible
to predict exact timing behavior with every possible Inform game in real-world
scenarios; marking NIFs as
["dirty"](https://www.erlang.org/doc/apps/erts/erl_nif.html#dirty_nifs)
will provide a fallback in cases where execution times exceed the 1ms threshold.

> [!WARNING]
> Configurable NIF scheduling strategy is not yet implemented, but on roadmap.

Zmex internally relies on [Folly's](https://github.com/bkirwi/folly) implementation
of a Z-machine in Rust,
[Encrusted Heart](https://github.com/bkirwi/folly/tree/master/encrusted-heart). This
work in turn is based on the original
[Encrusted](https://github.com/DeMille/encrusted),
extended to support Inform v4, v5, and v8 (along with myriad other improvements). Both
projects are MIT licensed.

Enormous thanks to all contributors of these projects, for their incredible work
making this all possible, and for gifting this work to avid explorers of this
wonderful technology through permissive OSS licensing.

<!-- /@moduledoc Zmex -->

## License

MIT

