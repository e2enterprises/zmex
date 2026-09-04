defmodule Mix.Tasks.Loop do
  use Mix.Task

  def run(argv) do
    ZmexCli.loop(argv)
  end
end
