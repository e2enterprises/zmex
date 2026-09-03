defmodule Mix.Tasks.ZMex do
  use Mix.Task

  def run(argv) do
    ZMexCli.main(argv)
  end
end
