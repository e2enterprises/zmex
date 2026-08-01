defmodule Mix.Tasks.Read do
  use Mix.Task

  def run(argv) do
    ExzmCli.step(argv)
  end
end
