defmodule ExzmCli.EncrustedNif do
  use Rustler, otp_app: :exzm_cli, crate: "encrusted_nif"

  def read(_story, _state, _input) do
    :erlang.nif_error(:nif_not_loaded)
  end
end

defmodule ExzmCli do
  alias ExzmCli.EncrustedNif

  def read(argv) do
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

    story_binary =
      case File.read(story_path) do
        {:ok, story_data} -> story_data
        _ -> raise "Failed to read story file."
      end

    save_binary =
      if reset do
        ""
      else
        case File.read(save_path) do
          {:ok, save_data} -> save_data
          _ -> ""
        end
      end

    input_str = Enum.join(input, " ")

    if verbose do
      IO.puts("\nDiagnostics")
      IO.puts("-----------")
      IO.puts("  Story | #{story_path} · #{byte_size(story_binary) / 1000}kb")
      IO.puts("   Save | #{save_path} · #{byte_size(save_binary) / 1000}kb")
      IO.puts("  Input | #{inspect(input)} · #{String.length(input_str)} chars")
      IO.puts("Options | #{inspect(reset: reset, help: help, verbose: verbose)}")
    end

    {time_microseconds, {new_save_binary, output}} =
      if verbose do
        :timer.tc(&EncrustedNif.read/3, [story_binary, save_binary, input_str])
      else
        {nil, EncrustedNif.read(story_binary, save_binary, input_str)}
      end

    if time_microseconds != nil do
      IO.puts(" Timing | Z-machine NIF call took #{time_microseconds / 1000}ms\n")
    end

    case File.write(save_path, new_save_binary) do
      :ok -> true
      _ -> raise "Failed to write save data to file."
    end

    IO.write(output)
  end
end
