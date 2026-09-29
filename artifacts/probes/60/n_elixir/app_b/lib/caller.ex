defmodule AppB.Caller do
  # EXPECTED (stated before run): compiles with no error and no warning about
  # @moduledoc false; `mix run` prints 84 (AppA.Hidden.secret(42)).
  def go, do: AppA.Hidden.secret(42)
end
