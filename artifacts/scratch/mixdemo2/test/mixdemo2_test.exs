defmodule Mixdemo2Test do
  use ExUnit.Case
  doctest Mixdemo2

  test "greets the world" do
    assert Mixdemo2.hello() == :world
  end
end
