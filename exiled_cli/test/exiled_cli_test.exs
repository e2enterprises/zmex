defmodule ExiledCliTest do
  use ExUnit.Case
  doctest ExiledCli

  test "greets the world" do
    assert ExiledCli.hello() == :world
  end
end
