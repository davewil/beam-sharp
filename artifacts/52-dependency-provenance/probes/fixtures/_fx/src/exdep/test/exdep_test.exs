defmodule ExdepTest do
  use ExUnit.Case
  doctest Exdep

  test "greets the world" do
    assert Exdep.hello() == :world
  end
end
