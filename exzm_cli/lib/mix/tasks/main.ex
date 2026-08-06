defmodule Mix.Tasks.Exzm do
  use Mix.Task

  def run(argv) do
    ExzmCli.main(argv)
  end
end
