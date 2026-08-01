defmodule ExzmCli do
  def step(argv) do
    args =
      OptionParser.parse!(
        argv,
        switches: [help: :boolean, reset: :boolean, verbose: :count],
        aliases: [h: :help, R: :reset, V: :verbose]
      )

    {options, [story_file | input]} = args

    reset = Keyword.get(options, :reset, false)
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

    input_str = Enum.join(input, " ")

    if verbose do
      IO.puts("\n Diagnostics")
      IO.puts(" -----------")
      IO.puts("   Story | #{story_path} · #{byte_size(story_data) / 1000}kb")
      IO.puts("    Save | #{save_path} · #{byte_size(save_data) / 1000}kb")
      IO.puts("   Input | #{inspect(input)} · #{String.length(input_str)} chars")
      IO.puts(" Options | #{inspect(reset: reset, help: help, verbose: verbose)}")
      IO.puts("  Timing | Loading story data : #{story_data_time / 1000}ms")

      if !reset do
        IO.puts("         | Loading save data  : #{save_data_time / 1000}ms")
      end
    end

    {new_save_data, output, diagnostics} =
      cond do
        !verbose and byte_size(save_data) == 0 ->
          {new_save_data, output} =
            Exzm.new_game(story_data, input_str)

          {new_save_data, output, nil}

        !!verbose and byte_size(save_data) == 0 ->
          Exzm.new_game(story_data, input_str, diagnostics: true)

        !verbose ->
          {new_save_data, output} =
            Exzm.continue(story_data, save_data, input_str)

          {new_save_data, output, nil}

        !!verbose ->
          Exzm.continue(story_data, save_data, input_str, diagnostics: true)
      end

    if verbose do
      IO.puts("         | Z-machine NIF call : #{diagnostics.nif_duration_ms}ms\n")
    end

    case File.write(save_path, new_save_data) do
      :ok -> true
      _ -> raise "Failed to write save data to file."
    end

    IO.write(output)
  end
end
