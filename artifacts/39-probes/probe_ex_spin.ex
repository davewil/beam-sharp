# Probe for ticket 39 sub-decision 1: verbatim copy of aoc/bench/bench_ex.ex's
# wrap/1, hit/1 and spin/4, with a new spin_only/2 entry point.
defmodule ProbeExSpin do
  def wrap(n), do: rem(rem(n, 100) + 100, 100)

  def hit(0), do: 1
  def hit(_), do: 0

  def spin(pos, _step, 0, zeros), do: {pos, zeros}
  def spin(pos, step, left, zeros) do
    next = wrap(pos + step)
    spin(next, step, left - 1, zeros + hit(next))
  end

  def spin_only(step, left), do: spin(50, step, left, 0)
end
