defmodule Mix.Tasks.Loop do
  use Mix.Task

  def run(argv) do
    ExzmCli.loop(argv)
  end
end
