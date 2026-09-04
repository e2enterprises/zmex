defmodule Mix.Tasks.Play do
  use Mix.Task

  def run(argv) do
    ZmexCli.main(argv)
  end
end
