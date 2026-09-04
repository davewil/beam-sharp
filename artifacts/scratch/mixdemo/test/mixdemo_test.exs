defmodule MixdemoTest do
  use ExUnit.Case
  doctest Mixdemo

  test "greets the world" do
    assert Mixdemo.hello() == :world
  end
end
