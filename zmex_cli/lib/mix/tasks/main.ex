defmodule Mix.Tasks.Zmex do
  use Mix.Task

  def run(argv) do
    ZmexCli.main(argv)
  end
end
