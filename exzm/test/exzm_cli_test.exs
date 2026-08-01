defmodule ExzmTest do
  use ExUnit.Case
  doctest Exzm

  test "greets the world" do
    assert Exzm.hello() == :world
  end
end
