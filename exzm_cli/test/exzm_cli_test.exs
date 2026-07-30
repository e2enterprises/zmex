defmodule ExzmCliTest do
  use ExUnit.Case
  doctest ExzmCli

  test "greets the world" do
    assert ExzmCli.hello() == :world
  end
end
