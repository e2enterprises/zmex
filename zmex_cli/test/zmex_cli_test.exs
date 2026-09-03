defmodule ZMexCliTest do
  use ExUnit.Case
  doctest ZMexCli

  test "greets the world" do
    assert ZMexCli.hello() == :world
  end
end
