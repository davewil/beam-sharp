#!/bin/bash
# Probe 60/elixir: (a) @moduledoc false hides docs only; (b) a ~25-line compile tracer
# rejects a caller outside the callee's subtree. Elixir 1.14.0 / OTP 25.
cd "$(dirname "$0")"
W=$(mktemp -d); cp -r . $W; cd $W
echo "--- (a) @moduledoc false: call from an unrelated module still works"
cat > base.exs <<'X'
defmodule Hidden do
  @moduledoc false
  def f, do: :reachable
end
defmodule Anywhere do
  def g, do: Hidden.f()
end
IO.inspect(Anywhere.g(), label: "Anywhere.g()")
X
elixir base.exs 2>&1 | tee oa; grep -q 'reachable' oa || exit 1
echo "--- (b) tracer, allowed callers only (lib_ok)"
cat > drive.exs <<'X'
Code.require_file("tracer.exs")
Code.put_compiler_option(:tracers, [SubtreeTracer])
dir = System.argv() |> hd()
files = Path.wildcard(dir <> "/*.ex")
t0 = System.monotonic_time(:microsecond)
try do
  Code.compile_file(Enum.at(files, 0)); Enum.each(tl(files), &Code.compile_file/1)
  IO.puts("COMPILED OK: #{length(files)} file(s)")
  IO.puts("Shop.Orders.total(3) = #{Shop.Orders.total(3)}")
rescue
  e in CompileError -> IO.puts("REFUSED: " <> Exception.message(e)); System.halt(3)
after
  IO.puts("compile_us=#{System.monotonic_time(:microsecond) - t0}")
end
X
elixir drive.exs lib_ok | tee ob; grep -q "COMPILED OK" ob || exit 1
echo "--- (b) tracer, Shop.Reports names Shop.Orders.Internal.Helper (lib_bad)"
elixir drive.exs lib_bad | tee oc; grep -q "Shop.Reports may not name Shop.Orders.Internal.Helper" oc || exit 1
echo "--- (c) control: same lib_bad with NO tracer compiles"
cat > ctrl.exs <<'X'
Code.compile_file("lib_bad/a.ex"); Code.compile_file("lib_bad/b.ex"); IO.puts("control compiled; Shop.Reports.r(2)=#{Shop.Reports.r(2)}")
X
elixir ctrl.exs | tee od; grep -q "r(2)=4" od || exit 1
echo "--- (d) cost: 300 modules x 100 remote calls (30,000 remote_function events), with vs without tracer"
cat > gen.exs <<'X'
File.mkdir_p!("big")
File.write!("big/h.ex", "defmodule Shop.Orders.Internal.H do\n def f(x), do: x\nend\n")
for i <- 1..300 do
  calls = Enum.map_join(1..100, " + ", fn _ -> "Shop.Orders.Internal.H.f(1)" end)
  File.write!("big/m#{i}.ex", "defmodule Shop.Orders.M#{i} do\n def g, do: #{calls}\nend\n")
end
X
elixir gen.exs
cat > bench.exs <<'X'
[mode] = System.argv()
if mode == "trace", do: (Code.require_file("tracer.exs"); Code.put_compiler_option(:tracers, [SubtreeTracer]))
files = ["big/h.ex" | Path.wildcard("big/m*.ex")]
t0 = System.monotonic_time(:millisecond)
Enum.each(files, &Code.compile_file/1)
IO.puts("#{mode}: #{System.monotonic_time(:millisecond) - t0} ms for #{length(files)} files")
X
for i in 1 2 3; do elixir bench.exs plain; elixir bench.exs trace; done | tee oe
echo "--- (e) bypass: dynamic apply/3 is invisible to the tracer (BEAM has no per-caller export)"
mkdir -p dyn; cp lib_ok/a.ex dyn/a.ex
cat > dyn/b.ex <<'X'
defmodule Shop.Reports do
  def r(x), do: apply(Module.concat(Shop.Orders.Internal, Helper), :recompute, [x])
end
X
elixir drive.exs dyn | tee of; grep -q "COMPILED OK" of || exit 1
echo "--- (f) the tracer event is documented in the installed Code module docs chunk"
elixir -e '{:docs_v1,_,_,_,%{"en"=>m},_,_}=Code.fetch_docs(Code); {s,_}=:binary.match(m,"{:remote_function, meta, module, name, arity}"); IO.puts(binary_part(m,s,230))' | tee og; grep -q remote_function og || exit 1
echo "tracer.exs non-blank lines: $(grep -c . tracer.exs)"
echo OK
