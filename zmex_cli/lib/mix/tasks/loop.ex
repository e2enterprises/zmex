defmodule Mix.Tasks.Loop do
  use Mix.Task

  def run(argv) do
    ZMexCli.loop(argv)
  end
end
