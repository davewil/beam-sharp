# Probe 13: runtime/observability cost of alias functions. Uses beams produced by 11_alias_inject.exs
# (OUT=dir). Args: <dir-with-aliased-Shop.beam> <label>
[dir, label] = System.argv()
Code.prepend_path(dir)
IO.puts("===== #{label}")
bad = %{Kind: :"MyApp.Order", Id: 9, Total: 5}
show = fn l, f ->
  try do f.() rescue e -> IO.puts("#{l}: #{inspect(e.__struct__)}"); IO.puts(Exception.format_stacktrace(__STACKTRACE__)) end
end
show.("1. crash via ORIGINAL :Shop.\"Which\"/1", fn -> :Shop."Which"(bad) end)
show.("2. crash via ALIAS :Shop.which/1      ", fn -> :Shop.which(bad) end)
IO.puts("--- exports now: " <> inspect(:Shop.module_info(:exports) |> Enum.reject(&(elem(&1,0) in [:module_info, :bs@type_atoms])) |> Enum.sort()))
IO.puts("--- global call tracing on the ORIGINAL (what dbg/recon/observer trace users write)")
count = fn via ->
  :erlang.trace_pattern({:Shop, :Amount, 1}, true, [:global])
  :erlang.trace(self(), true, [:call])
  o = :Shop."New"(1)
  via.(o)
  :erlang.trace(self(), false, [:call])
  :erlang.trace_pattern({:Shop, :Amount, 1}, false, [:global])
  n = Stream.repeatedly(fn -> receive do {:trace, _, :call, _} -> 1 after 0 -> nil end end) |> Enum.take_while(& &1) |> length()
  n
end
IO.puts("trace events when caller uses original name : #{count.(fn o -> :Shop."Amount"(o) end)}")
IO.puts("trace events when caller uses the alias      : #{count.(fn o -> :Shop.amount(o) end)}   (0 => the alias hid the call from a global trace)")
IO.puts("--- current_function / process_info inside a slow call is not measured: tail call leaves no frame")
