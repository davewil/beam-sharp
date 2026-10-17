# P6: file:line of the neighbour messages, recovered from the installed .beam debug_info
# (this box has Elixir's ebin dirs only, not its .ex sources). Line numbers are the
# ones Elixir's compiler recorded for the source it was built from (Elixir 1.14.0).
needles = ["yet to be defined", "depend on :", "extra_applications"]

defmodule H do
  def anno_line(a, _), do: :erl_anno.line(a)
  def hits(path, needle) do
    case :beam_lib.chunks(path, [:debug_info]) do
      {:ok, {mod, [debug_info: {:debug_info_v1, backend, data}]}} ->
        case backend.debug_info(:erlang_v1, mod, data, []) do
          {:ok, forms} ->
            file = Enum.find_value(forms, fn {:attribute, _, :file, {f, _}} -> to_string(f); _ -> nil end)
            {mod, file, scan(forms, needle, [])}
          _ -> nil
        end
      _ -> nil
    end
  end
  defp scan(t, n, acc) when is_tuple(t) do
    case t do
      {:bin, _, [{:bin_element, a, {:string, _, s}, _, _} | _]} ->
        if String.contains?(to_string(s), n), do: [{:erl_anno.line(a), String.slice(to_string(s), 0, 90)} | acc], else: acc
      _ -> scan(Tuple.to_list(t), n, acc)
    end
  end
  defp scan([h | t], n, acc), do: scan(t, n, scan(h, n, acc))
  defp scan(_, _, acc), do: acc
end

paths = Path.wildcard("/usr/lib/elixir/lib/{elixir,mix}/ebin/*.beam")
for needle <- needles, path <- paths,
    {mod, file, [_ | _] = hits} <- [H.hits(String.to_charlist(path), needle)] do
  for {line, str} <- Enum.uniq(hits), do: IO.puts("#{needle |> inspect}  #{mod}  #{file}:#{line}  #{inspect(str)}")
end
