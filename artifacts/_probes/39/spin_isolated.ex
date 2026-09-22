defmodule SpinIsolated do
  # Only run/1 is public, matching beam-sharp's Day01Isolated (see the
  # comment in spin_isolated.erl for why this matters to the measurement).
  defp wrap(n), do: rem(rem(n, 100) + 100, 100)

  defp hit(0), do: 1
  defp hit(_), do: 0

  defp spin(pos, _step, 0, zeros), do: {pos, zeros}

  defp spin(pos, step, left, zeros) do
    next = wrap(pos + step)
    spin(next, step, left - 1, zeros + hit(next))
  end

  def run(left), do: spin(50, 1, left, 0)
end
