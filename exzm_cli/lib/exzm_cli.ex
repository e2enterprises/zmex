defmodule ExzmCli do
  def parse_seed(seed) do
    case Base.decode64(seed, padding: false) do
      {:ok, term} -> :erlang.binary_to_term(term)
      _ -> raise(ArgumentError, "invalid base64 seed value (seed: #{seed})")
    end
  end

  def serialize_seed({a, b, c, d} = seed)
      when is_number(a) and is_number(b) and is_number(c) and is_number(d) do
    seed |> :erlang.term_to_binary() |> Base.encode64(padding: false)
  end

  def format_nif_diagnostic_records(records) do
    for {duration, _input, _output, _result} <- records, into: "" do
      case duration do
        nil -> ""
        duration when duration > 1 -> "#{duration}ms -> "
        _ -> "#{duration}ms ✔ -> "
      end
    end
    |> String.replace_suffix(" -> ", "")
  end

  def loop(argv \\ nil) do
    args =
      OptionParser.parse!(
        argv || System.argv(),
        switches: [reset: :boolean, seed: :string, help: :boolean, verbose: :boolean],
        aliases: [R: :reset, s: :seed, h: :help, V: :verbose]
      )

    {options, [story_file | _input]} = args

    input =
      if Keyword.get(options, :reset, false) do
        ""
      else
        IO.gets("\n\n> ") |> String.trim()
      end

    new_args = OptionParser.to_argv(options) ++ [story_file, input]

    main(new_args)

    new_args_without_reset = new_args |> List.delete("--reset") |> List.delete("-R")

    loop(new_args_without_reset)
  end

  def main(argv \\ nil) do
    argv || System.argv()

    args =
      OptionParser.parse!(
        argv,
        switches: [reset: :boolean, seed: :string, help: :boolean, verbose: :boolean],
        aliases: [R: :reset, s: :seed, h: :help, V: :verbose]
      )

    {options, [story_file | input]} = args

    reset = Keyword.get(options, :reset, false)
    seed = Keyword.get(options, :seed, nil)
    help = Keyword.get(options, :help, false)
    verbose = Keyword.get(options, :verbose, false)

    story_path = Path.join("../stories", story_file)

    save_path =
      Path.join(
        Path.dirname(story_path),
        Path.basename(story_path, Path.extname(story_path)) <>
          "_save.qz"
      )

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

    {story_time, story} =
      cond do
        verbose -> :timer.tc(load_story, [])
        true -> {nil, load_story.()}
      end

    {save_time, save} =
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
            Exzm.new_game(story, input_str,
              seed: seed,
              step_through_blank: true
            )

          {new_save, output, seed, nil}

        !!verbose and byte_size(save) == 0 ->
          Exzm.new_game(story, input_str,
            seed: seed,
            step_through_blank: true,
            diagnostics: true
          )

        !verbose ->
          {new_save, output, seed} =
            Exzm.continue(story, save, input_str,
              seed: seed,
              step_through_blank: true
            )

          {new_save, output, seed, nil}

        !!verbose ->
          Exzm.continue(story, save, input_str,
            seed: seed,
            step_through_blank: true,
            diagnostics: true
          )
      end

    if verbose do
      IO.puts("    Seed | b64 : #{serialize_seed(seed)}")
      IO.puts("         | raw : #{inspect(seed)}")
      IO.puts("  Timing | Load Story Data                    : #{story_time / 1000}ms")

      if !reset do
        IO.puts("         | Loading Save Data                  : #{save_time / 1000}ms")
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
