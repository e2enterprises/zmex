defmodule ZmexCliTest do
  use ExUnit.Case
  doctest ZmexCli

  test "greets the world" do
    assert ZmexCli.hello() == :world
  end
end
