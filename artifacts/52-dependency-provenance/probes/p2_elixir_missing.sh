#!/bin/sh
# PROBE 2 (ii) — Elixir 1.14: compile a file that references an unavailable module.
# PREDICTION: elixirc succeeds (exit 0) and prints a compile-time WARNING "Req.new/1 is undefined (module Req is not
# available or is yet to be defined)" (the compiler tracer knows the module is absent); nothing fails until run time,
# where the call raises UndefinedFunctionError. Second variant: a struct literal %Req.Request{} of an unavailable module
# is a hard compile ERROR (structs need the definition at compile time). Third: an `alias`/`import Req` is an error.
cd "$(dirname "$0")"; W=work/p2; rm -rf $W; mkdir -p $W; cd $W
cat > call.ex <<'EOS'
defmodule Caller do
  def go, do: Req.new(url: "x")
end
EOS
cat > strukt.ex <<'EOS'
defmodule Strukt do
  def go, do: %Req.Request{}
end
EOS
cat > imp.ex <<'EOS'
defmodule Imp do
  import Req
  def go, do: 1
end
EOS
for f in call strukt imp; do
  echo "== elixirc $f.ex"; env -u ERL_LIBS elixirc $f.ex; echo "exit=$?"
done
echo "== run Caller.go/0 (beam produced by call.ex)"
env -u ERL_LIBS elixir -pa . -e 'try do Caller.go() rescue e -> IO.puts(Exception.message(e)); IO.inspect(__STACKTRACE__, limit: 3) end'
