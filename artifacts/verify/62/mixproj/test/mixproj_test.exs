defmodule MixprojTest do
  use ExUnit.Case
  doctest Mixproj

  test "greets the world" do
    assert Mixproj.hello() == :world
  end
end
