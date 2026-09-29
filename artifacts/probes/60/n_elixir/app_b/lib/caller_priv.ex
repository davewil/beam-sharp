defmodule AppB.CallerPriv do
  # EXPECTED: the ONLY compile-time refusal: a defp is undefined from outside.
  def go, do: AppA.Hidden.really_private(1)
end
