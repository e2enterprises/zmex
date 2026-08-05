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

  def step(argv) do
    args =
      OptionParser.parse!(
        argv,
        switches: [reset: :boolean, seed: :string, help: :boolean, verbose: :count],
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

    load_story_data = fn ->
      case File.read(story_path) do
        {:ok, story_data} -> story_data
        _ -> raise "Failed to read story file."
      end
    end

    load_save_data = fn ->
      case File.read(save_path) do
        {:ok, save_data} -> save_data
        _ -> ""
      end
    end

    {story_data_time, story_data} =
      cond do
        verbose -> :timer.tc(load_story_data, [])
        true -> {nil, load_story_data.()}
      end

    {save_data_time, save_data} =
      cond do
        reset -> {nil, <<>>}
        verbose -> :timer.tc(load_save_data, [])
        true -> {nil, load_save_data.()}
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
      IO.puts("   Story | #{story_path} · #{byte_size(story_data) / 1000}kb")
      IO.puts("    Save | #{save_path} · #{byte_size(save_data) / 1000}kb")
      IO.puts("   Input | #{inspect(input)} · #{String.length(input_str)} chars")
      IO.puts(" Options | #{inspect(reset: reset, help: help, verbose: verbose)}")
    end

    {new_save_data, output, seed, diagnostics} =
      cond do
        !verbose and byte_size(save_data) == 0 ->
          {new_save_data, output, seed} =
            Exzm.new_game(story_data, input_str,
              seed: seed,
              step_through_blank: true
            )

          {new_save_data, output, seed, nil}

        !!verbose and byte_size(save_data) == 0 ->
          Exzm.new_game(story_data, input_str,
            seed: seed,
            step_through_blank: true,
            diagnostics: true
          )

        !verbose ->
          {new_save_data, output, seed} =
            Exzm.continue(story_data, save_data, input_str,
              seed: seed,
              step_through_blank: true
            )

          {new_save_data, output, seed, nil}

        !!verbose ->
          Exzm.continue(story_data, save_data, input_str,
            seed: seed,
            step_through_blank: true,
            diagnostics: true
          )
      end

    if verbose do
      IO.puts("    Seed | b64: #{serialize_seed(seed)}")
      IO.puts("         | raw: #{inspect(seed)}")
      IO.puts("  Timing | Loading story data     : #{story_data_time / 1000}ms")

      if !reset do
        IO.puts("         | Loading save data      : #{save_data_time / 1000}ms")
      end

      IO.puts("         | Prime Z-machine NIF call     : #{diagnostics.prime_zmachine_nif_ms}ms")

      if diagnostics.send_line_to_zmachine_nif_ms > 0 do
        IO.puts(
          "         | Send Line Z-machine NIF call : #{diagnostics.send_line_to_zmachine_nif_ms}ms"
        )
      end

      if diagnostics.send_char_to_zmachine_nif_ms > 0 do
        IO.puts(
          "         | Send Char Z-machine NIF call : #{diagnostics.send_char_to_zmachine_nif_ms}ms"
        )
      end

      IO.puts("")
    end

    case File.write(save_path, new_save_data) do
      :ok -> true
      _ -> raise "Failed to write save data to file."
    end

    IO.write(output)
  end
end
