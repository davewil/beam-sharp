defmodule BenchEx do
  defp wrap(n), do: rem(rem(n, 100) + 100, 100)

  defp hit(0), do: 1
  defp hit(_), do: 0

  defp spin(pos, _step, 0, zeros), do: {pos, zeros}

  defp spin(pos, step, left, zeros) do
    next = wrap(pos + step)
    spin(next, step, left - 1, zeros + hit(next))
  end

  defp sign(0), do: 1
  defp sign(d) when d > 0, do: 1
  defp sign(d) when d < 0, do: -1

  defp size_(d) when d >= 0, do: d
  defp size_(d) when d < 0, do: -d

  defp clicks([], _pos, zeros), do: zeros

  defp clicks([d | rest], pos, zeros) do
    {next, hits} = spin(pos, sign(d), size_(d), zeros)
    clicks(rest, next, hits)
  end

  def part_two(rs), do: clicks(rs, 50, 0)
end
