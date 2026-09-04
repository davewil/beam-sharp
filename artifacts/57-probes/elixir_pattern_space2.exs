defmodule SpaceTest2 do
  def f(- 5), do: :spaced
end
IO.inspect(SpaceTest2.f(-5), label: "f(-5) via pattern `- 5` (spaced)")
