defmodule Mix.Tasks.Play do
  use Mix.Task

  def run(argv) do
    ZMexCli.main(argv)
  end
end
