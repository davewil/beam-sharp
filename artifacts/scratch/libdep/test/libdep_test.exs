defmodule LibdepTest do
  use ExUnit.Case
  doctest Libdep

  test "greets the world" do
    assert Libdep.hello() == :world
  end
end
