defmodule ZmexCli do
  defp generate_random_seed() do
    max = 2 ** 31
    min = -max
    rng = fn -> Enum.random(min..max) end
    {rng.(), rng.(), rng.(), rng.()}
  end

  defp parse_seed(seed) do
    case Base.decode64(seed, padding: false) do
      {:ok, term} -> :erlang.binary_to_term(term)
      _ -> raise(ArgumentError, "invalid base64 seed value (seed: #{seed})")
    end
  end

  defp serialize_seed({a, b, c, d} = seed)
       when is_number(a) and is_number(b) and is_number(c) and is_number(d) do
    seed |> :erlang.term_to_binary() |> Base.encode64(padding: false)
  end

  defp format_nif_diagnostic_records(records) do
    records
    |> Stream.map(fn {nif, dirty?, called?, duration, _input, _output, _result} ->
      {nif, dirty?, called?, duration}
    end)
    |> Stream.filter(fn {_nif, _dirty?, called?, _duration} -> called? end)
    |> Stream.map(fn {nif, dirty?, _called?, duration} ->
      dirty =
        if dirty? do
          "_dirty_cpu"
        else
          ""
        end

      if duration <= 1 do
        "#{duration}ms ✔ #{nif}#{dirty}"
      else
        "#{duration}ms #{nif}#{dirty}"
      end
    end)
    |> Enum.join(" -> ")
  end

  defp get_story_path(story_file) do
    Path.join("../native/encrusted_nif/encrusted-heart/tests", story_file)
  end

  defp get_save_path(story_path) do
    Path.join(
      Path.dirname(story_path),
      Path.basename(story_path, Path.extname(story_path)) <>
        "_save.qz"
    )
  end

  def loop(argv \\ []) do
    args =
      OptionParser.parse!(
        argv || System.argv(),
        switches: [
          reset: :boolean,
          seed: :string,
          help: :boolean,
          verbose: :boolean,
          diagnostics: :boolean,
          dirtynifs: :string
        ],
        aliases: [R: :reset, s: :seed, h: :help, V: :verbose, d: :diagnostics, D: :diagnostics]
      )

    {options, [story_file | _input]} = args

    reset? = Keyword.get(options, :reset, false)
    has_seed? = !!Keyword.get(options, :seed)
    continuing? = story_file |> get_story_path() |> get_save_path() |> File.exists?()

    input =
      cond do
        # Entirely new game; title text will be shown:
        reset? or not continuing? -> ""
        # Ensure game gives player context before 1st prompt ("look" at surroundings):
        not has_seed? -> "look"
        # Otherwise, normal game loop; prompt the player for input:
        true -> IO.gets("\n\n> ") |> String.trim()
      end

    options =
      if has_seed? do
        options
      else
        seed = generate_random_seed() |> serialize_seed()
        Keyword.put(options, :seed, seed)
      end

    new_args = OptionParser.to_argv(options) ++ [story_file, input]

    main(new_args)

    new_args_without_reset = new_args |> List.delete("--reset") |> List.delete("-R")

    loop(new_args_without_reset)
  end

  def main(argv \\ []) do
    argv || System.argv()

    args =
      OptionParser.parse!(
        argv,
        switches: [
          reset: :boolean,
          seed: :string,
          help: :boolean,
          verbose: :boolean,
          diagnostics: :boolean,
          dirtynifs: :string
        ],
        aliases: [R: :reset, s: :seed, h: :help, V: :verbose, d: :diagnostics, D: :diagnostics]
      )

    {options, [story_file | input]} = args

    reset = Keyword.get(options, :reset, false)
    seed = Keyword.get(options, :seed, nil)
    help = Keyword.get(options, :help, false)
    diagnostics = Keyword.get(options, :diagnostics, false)
    verbose = Keyword.get(options, :verbose, diagnostics)
    dirty_nifs = Keyword.get(options, :dirtynifs, "")

    dirty_nifs = dirty_nifs |> String.split(",") |> Enum.map(&String.to_atom/1)
    story_path = get_story_path(story_file)
    save_path = get_save_path(story_path)

    load_story = fn ->
      case File.read(story_path) do
        {:ok, story} -> story
        _ -> raise "Failed to read story file."
      end
    end

    load_save = fn ->
      case File.read(save_path) do
        {:ok, save} -> save
        _ -> ""
      end
    end

    {load_story_microsec, story} =
      cond do
        verbose -> :timer.tc(load_story, [])
        true -> {nil, load_story.()}
      end

    {load_save_microsec, save} =
      cond do
        reset -> {nil, <<>>}
        verbose -> :timer.tc(load_save, [])
        true -> {nil, load_save.()}
      end

    seed =
      if seed == nil do
        seed
      else
        seed = parse_seed(seed)

        case seed do
          {a, b, c, d} when is_number(a) and is_number(b) and is_number(c) and is_number(d) ->
            {a, b, c, d}

          _ ->
            raise(ArgumentError, "invalid seed")
        end
      end

    input_str = Enum.join(input, " ")

    if verbose do
      IO.puts("\n Diagnostics")
      IO.puts(" -----------")
      IO.puts("    Args | #{inspect(argv)}")
      IO.puts("   Story | #{story_path} · #{byte_size(story) / 1000}kb")
      IO.puts("    Save | #{save_path} · #{byte_size(save) / 1000}kb")
      IO.puts("   Input | #{inspect(input)} · #{String.length(input_str)} chars")
      IO.puts(" Options | #{inspect(reset: reset, help: help, verbose: verbose)}")
    end

    {new_save, output, seed, diagnostics} =
      cond do
        !verbose and byte_size(save) == 0 ->
          {new_save, output, seed} =
            Zmex.new_game(story, input_str,
              seed: seed,
              step_through_blank: true,
              dirty_nifs: dirty_nifs
            )

          {new_save, output, seed, nil}

        !!verbose and byte_size(save) == 0 ->
          Zmex.new_game(story, input_str,
            seed: seed,
            step_through_blank: true,
            diagnostics: true,
            dirty_nifs: dirty_nifs
          )

        !verbose ->
          {new_save, output, seed} =
            Zmex.continue(story, save, input_str,
              seed: seed,
              step_through_blank: true,
              dirty_nifs: dirty_nifs
            )

          {new_save, output, seed, nil}

        true ->
          Zmex.continue(story, save, input_str,
            seed: seed,
            step_through_blank: true,
            diagnostics: true,
            dirty_nifs: dirty_nifs
          )
      end

    if verbose do
      IO.puts("    Seed | b64 : #{serialize_seed(seed)}")
      IO.puts("         | raw : #{inspect(seed)}")
      IO.puts("  Timing | Load Story Data                    : #{load_story_microsec / 1000}ms")

      if !reset do
        IO.puts("         | Loading Save Data                  : #{load_save_microsec / 1000}ms")
      end

      if diagnostics.seed_nif > 0 do
        IO.puts(
          "         | Compute seed NIF call              : #{format_nif_diagnostic_records(diagnostics.seed_nif)}"
        )
      end

      IO.puts(
        "         | Init Z-machine Step NIF call       : #{format_nif_diagnostic_records(diagnostics.init_nif)}"
      )

      IO.puts(
        "         | Pre-input Z-machine Step NIF call  : #{format_nif_diagnostic_records(diagnostics.step_1_nif)}"
      )

      case format_nif_diagnostic_records(diagnostics.send_line_nif) do
        "" -> {}
        formatted -> IO.puts("         | Send-Line Z-machine NIF call       : #{formatted}")
      end

      case format_nif_diagnostic_records(diagnostics.send_char_nif) do
        "" ->
          {}

        formatted ->
          IO.puts("         | Send-Char Z-machine NIF call       : #{formatted}")
      end

      case format_nif_diagnostic_records(diagnostics.unicode_table_nif) do
        "" ->
          {}

        formatted ->
          IO.puts("         | Unicode Table Z-machine NIF call   : #{formatted}")
      end

      IO.puts(
        "         | Post-Input Z-machine Step NIF call : #{format_nif_diagnostic_records(diagnostics.step_2_nif)}"
      )

      IO.puts(
        "         | Z-machine Output NIF call          : #{format_nif_diagnostic_records(diagnostics.output_nif)}"
      )

      IO.puts(
        "         | Z-machine Save NIF call            : #{format_nif_diagnostic_records(diagnostics.save_nif)}"
      )

      IO.puts("")
    end

    case File.write(save_path, new_save) do
      :ok -> true
      _ -> raise "Failed to write save data to file."
    end

    IO.write(output)
  end
end
