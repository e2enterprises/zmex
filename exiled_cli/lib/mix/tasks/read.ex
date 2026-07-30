defmodule Mix.Tasks.Read do
  use Mix.Task

  def run(argv) do
    ExiledCli.read(argv)
  end
end
