defmodule BenchEx do
  @spec wrap(integer()) :: integer()
  defp wrap(n), do: rem(rem(n, 100) + 100, 100)
  defp hit(0), do: 1
  defp hit(_), do: 0
  defp spin(pos, _step, 0, zeros), do: {pos, zeros}
  defp spin(pos, step, left, zeros) do
    next = wrap(pos + step)
    spin(next, step, left - 1, zeros + hit(next))
  end
  def part_two(rs), do: clicks(rs, 50, 0)
  defp clicks([], _pos, zeros), do: zeros
  defp clicks([d | rest], pos, zeros) do
    {next, hits} = spin(pos, if(d < 0, do: -1, else: 1), abs(d), zeros)
    clicks(rest, next, hits)
  end
end
