defmodule ExiledCli do
  def main(argv) do
    args =
      OptionParser.parse!(
        argv,
        switches: [help: :boolean, reset: :boolean, verbose: :count],
        aliases: [h: :help, R: :reset]
      )

    {options, [story | input]} = args

    reset = Keyword.get(options, :reset, false)
    help = Keyword.get(options, :help, false)
    verbose = Keyword.get(options, :verbose, false)

    if verbose do
      IO.puts("Story: #{story}")
      IO.puts("Input: #{inspect(input)}")
      IO.puts("Optns: #{inspect(reset: reset, help: help, verbose: verbose)}")
    end
  end
end
