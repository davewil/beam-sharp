#!/usr/bin/env bash
# p10 — the Req binding of prototype 51a, written with the application named per `using` block (spelling: `using :M in :app {`),
# compiled by the PATCHED copy of the compiler (patch_compiler.py inline). Real Req/hex.pm is unreachable here (proxy), so the `req`
# application is a 6-line stand-in with the same module name and `new/1`; Elixir and OTP are the real installed trees.
# Claims:
#   R1  (visual, see the printed source) one realistic module draws on THREE applications (req, elixir, stdlib) + a preloaded module (erlang): per-block naming is
#       not redundant here -- no application repeats
#   R2  with every app on ERL_LIBS it compiles and runs
#   R3  CONTROL: remove only `req` from ERL_LIBS -> refused at compile time naming `req` (the exact failure ticket 52 describes,
#       moved from run time to compile time)
#   R4  `:erlang` has no owning application; the only honest spelling is `in :erts` (erts is a real application dir): measured
#   R5  if naming were REQUIRED on every block, how many of the 18 `using :atom` blocks in compiler/examples would need editing: all 18
source "$(dirname "$0")/common.sh"
python3 "$PROBES/patch_compiler.py" inline "$WORK/bsc-in" | sed 's/^/   /'
printf '#!/usr/bin/env bash\nexec erl -noshell -pa %s/bsc-in/ebin -eval '"'"'bsc:main(init:get_plain_arguments())'"'"' -extra "$@"\n' "$WORK" > "$WORK/bsc-in.sh"; chmod +x "$WORK/bsc-in.sh"
mkdir -p "$WORK/libs/req-0.7.3/ebin" "$WORK/erl"
cat > "$WORK/erl/Elixir.Req.erl" <<'EOT'
-module('Elixir.Req').
-export([new/1]).
new(Opts) -> #{'__struct__' => 'Elixir.Req.Request', method => proplists:get_value(method, Opts, get)}.
EOT
erlc -o "$WORK/libs/req-0.7.3/ebin" "$WORK/erl/Elixir.Req.erl"
echo '{application,req,[{vsn,"0.7.3"},{modules,[]},{registered,[]},{applications,[kernel,stdlib,elixir]}]}.' > "$WORK/libs/req-0.7.3/ebin/req.app"
EXL=/tmp/claude-0/mm/root/envs/b/lib/elixir/lib
bs_module Req "using :'Elixir.Req' in :req {
    term new(list<(atom, term)> opts)
}

using :'Elixir.Application' in :elixir {
    term ensure_all_started(atom app)
}

using :maps in :stdlib {
    term get(atom k, term m)
}

using :erlang in :erts {
    int system_time(atom unit)
}

public term Method()
Method() -> :maps.get(:method, :'Elixir.Req'.new([(:method, :post)]))

public bool Started()
Started() -> :erlang.system_time(:second) > 0"
cat "$WORK/src/Req/Req.bs" | sed 's/^/   | /'
echo "== R1/R2 all applications on ERL_LIBS"
r=$(ERL_LIBS="$EXL:$WORK/libs" "$WORK/bsc-in.sh" --src-root "$WORK/src" -o "$WORK/o" "$WORK/src/Req" Method 2>&1); echo "Method() -> $r"; expect "R2 runs" ":post" "$r"
echo "== R3 control: req removed"
r=$(ERL_LIBS="$EXL" "$WORK/bsc-in.sh" --src-root "$WORK/src" -o "$WORK/o3" "$WORK/src/Req" Method 2>&1 | sed "s|$WORK/||"); echo "$r"
expect "R3 refused at compile time, naming req" "application \`req\`" "$r"; expect_not "R3 not a run-time crash" "crashed" "$r"
echo "== R3b same source under the STOCK compiler (control for 'the delta is what moved it'):"
sed "s/ in :[a-z]* {/ {/" "$WORK/src/Req/Req.bs" > "$WORK/src/Req/Req.stock"; mkdir -p "$WORK/stock/Req"; cp "$WORK/src/Req/Req.stock" "$WORK/stock/Req/Req.bs"
r=$(ERL_LIBS="$EXL" $BSC --src-root "$WORK/stock" -o "$WORK/o4" "$WORK/stock/Req" Method 2>&1); echo "stock, req absent: $r"; expect "R3b stock compiles it and dies at run time" "crashed: error:undef" "$r"
echo "== R4 the :erlang block"
r=$(ERL_LIBS="$EXL:$WORK/libs" "$WORK/bsc-in.sh" --src-root "$WORK/src" -o "$WORK/o5" "$WORK/src/Req" Started 2>&1); echo "Started() -> $r"; expect "R4 'in :erts' accepted" "true" "$r"
sed -i 's/using :erlang in :erts/using :erlang in :erlang/' "$WORK/src/Req/Req.bs"
r=$(ERL_LIBS="$EXL:$WORK/libs" "$WORK/bsc-in.sh" --src-root "$WORK/src" -o "$WORK/o6" "$WORK/src/Req" Started 2>&1 | sed "s|$WORK/||" | head -2); echo "'in :erlang' (the natural guess): $r"; expect "R4 control: 'in :erlang' is refused (no such application)" "application \`erlang\`" "$r"
echo "== R5 churn"
n=$(grep -rh "^using :" compiler/examples | wc -l); echo "using :atom blocks in compiler/examples that would need an 'in :app' if it were required: $n"
echo "   LANGUAGE.md fenced blocks with a foreign using: $(grep -c '^using :' LANGUAGE.md)"
finish
