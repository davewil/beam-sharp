# Does whitespace between '-' and the digit change whether it's accepted in
# pattern position? If Elixir's tokenizer/parser treats "-5" (no space) as a
# distinct negative-number token, "- 5" (with space) should behave differently
# or the same -- testing which.
defmodule SpaceTest do
  def f(-5), do: :tight
end
IO.inspect(SpaceTest.f(-5), label: "f(-5) [no space in call site, decl uses -5 tight]")
