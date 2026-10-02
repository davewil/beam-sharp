#!/usr/bin/env bash
# P3: how a compile-time presence check would work, and where each primitive lies.
set -u
LIBC="${P3_LIBC_NAME:-anything}"   # set to `req` to see the gate go RED (lib_dir then succeeds)
D="$(cd "$(dirname "$0")" && pwd)"; W="$(mktemp -d)"; cd "$W" || exit 2; fail=0
# three on-disk layouts of the same app 'req'
mkdir -p libA/req-0.7.3/ebin libB/_build/default/lib/req/ebin libC/$LIBC/ebin
cp "$D/src/Req_stub.erl" "$W/Elixir.Req.erl"   # erlc insists file name == module name
for e in libA/req-0.7.3/ebin libB/_build/default/lib/req/ebin libC/$LIBC/ebin; do
  erlc -o "$e" "$W/Elixir.Req.erl" || { echo "stub compile failed"; exit 2; }
  cat > "$e/req.app" <<'EOT'
{application,req,[{vsn,"0.7.3"},{modules,['Elixir.Req']},{applications,[kernel,stdlib,elixir,mint]}]}.
EOT
done
{
ls libA/req-0.7.3/ebin
probe='
io:format("lib_dir(req)=~p~n",[code:lib_dir(req)]),
io:format("which(Elixir.Req)=~p~n",[code:which(%27Elixir.Req%27)]),
io:format("where_is_file=~p~n",[code:where_is_file("Elixir.Req.beam")]),
io:format("app file via code:lib_dir -> ~p~n",[case code:lib_dir(req) of {error,_}=E->E; Dd->filelib:is_file(filename:join([Dd,"ebin","req.app"])) end]),
io:format("function_exported BEFORE load=~p~n",[erlang:function_exported(%27Elixir.Req%27,new,1)]),
io:format("stdlib present, module json (OTP27+ only): lib_dir(stdlib) ok=~p which(json)=~p~n",[element(1,{is_list(code:lib_dir(stdlib))}),code:which(json)]),
halt().'
probe=${probe//%27/\'}
run() { echo "--- $1"; shift; env "$@" erl -noshell -eval "$probe"; }
run "no ERL_LIBS, no -pa (control)" ERL_LIBS=
run "ERL_LIBS=libA  (app-vsn/ebin)" ERL_LIBS="$W/libA"
run "ERL_LIBS=libB/_build/default/lib (rebar3: no vsn in dir name)" ERL_LIBS="$W/libB/_build/default/lib"
echo "--- -pa libC/$LIBC/ebin (arbitrary dir name)"; erl -noshell -pa libC/$LIBC/ebin -eval "$probe"
echo "--- ensure_loaded runs on_load; which does not"
erl -noshell -pa libA/req-0.7.3/ebin -eval 'io:format("which -> ~p~n",[code:which(list_to_atom("Elixir.Req"))]), io:format("ensure_loaded ->~n"), io:format("~p~n",[code:ensure_loaded(list_to_atom("Elixir.Req"))]), io:format("function_exported AFTER load=~p~n",[erlang:function_exported(list_to_atom("Elixir.Req"),new,1)]), halt().'
echo "--- exports WITHOUT loading (beam_lib), what a check would use for arity"
erl -noshell -eval '{ok,{_,[{exports,E}]}}=beam_lib:chunks("libA/req-0.7.3/ebin/Elixir.Req.beam",[exports]), io:format("~p~n",[E]), halt().'
echo "--- cost of the primitives (1000 calls, microseconds each)"
ERL_LIBS="$W/libA" erl -noshell -eval '
T=fun(F)->{U,_}=timer:tc(fun()->[F()||_<-lists:seq(1,1000)] end), U/1000 end,
io:format("lib_dir=~.1f which=~.1f beam_lib exports=~.1f~n",[T(fun()->code:lib_dir(req) end),T(fun()->code:which(list_to_atom("Elixir.Req")) end),T(fun()->beam_lib:chunks("libA/req-0.7.3/ebin/Elixir.Req.beam",[exports]) end)]), halt().'
} 2>&1 | tee "$W/out.txt"
# expectations that would FALSIFY the claims if they did not hold
chk() { grep -q -- "$1" "$W/out.txt" || { echo "EXPECTATION FAILED: $1"; fail=1; }; }
# gate targets the -pa block ITSELF (the no-path control also prints bad_name, so a whole-output grep was circular)
blk=$(awk '/^--- -pa libC/{f=1;next} /^---/{f=0} f' "$W/out.txt")
echo "$blk" | grep -q 'lib_dir(req)={error,bad_name}' || { echo "EXPECTATION FAILED: lib_dir should be bad_name for -pa dir named '$LIBC'"; fail=1; }
echo "$blk" | grep -q 'which(Elixir.Req)="libC' || { echo "EXPECTATION FAILED: code:which should still find the module"; fail=1; }
chk 'lib_dir(req)=".*libB/_build/default/lib/req"'
chk 'ON_LOAD RAN'
chk 'which -> "libA'
chk '\[{module_info,0},{module_info,1},{new,1}\]'
echo "p3 fail=$fail"
rm -rf "${W:?}"; exit $fail
