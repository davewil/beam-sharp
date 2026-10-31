#!/usr/bin/env bash
# Probe (iii): two beams with the same module name in different code paths.
# Which wins (-pa / -pz / add_pathz order), what does code:clash/0 say, what does the loader do when a second
# version is loaded, and what does a release build (systools:make_script) say about duplicates across applications.
# A B# module `Json` (atom 'Json') declared by two packages is exactly this situation.
# Run: bash p3_same_module_two_paths.sh
set -u
T=$(mktemp -d); cd "$T"; mkdir d1 d2
for d in d1 d2; do
cat > $d/Json.erl <<X
-module('Json').
-export([who/0]).
who() -> $d.
X
erlc -o $d $d/Json.erl
done
echo "=== A: precedence by path order"
for flags in "-pa $T/d1 -pa $T/d2" "-pa $T/d2 -pa $T/d1" "-pz $T/d1 -pz $T/d2" "-pa $T/d1 -pz $T/d2" "-pz $T/d1 -pa $T/d2"; do
  printf '%-40s -> ' "$(echo $flags | sed "s#$T/##g")"
  erl -noshell $flags -eval "io:format(\"Json:who()=~p which=~s~n\",[ 'Json':who(), code:which('Json') ]),halt()." 2>&1 | sed "s#$T/##"
done
echo "=== B: code:clash/0 with both on the path (the tool that reports exactly this)"
erl -noshell -pa "$T/d1" -pa "$T/d2" -eval 'code:clash(), halt().' 2>&1 | sed "s#$T/##g" | head -8
echo "=== C: both versions loaded in one VM: second load_binary of same name; old-code limit"
cat > c.escript <<'X'
#!/usr/bin/env escript
main([D1, D2]) ->
  {ok, B1} = file:read_file(D1 ++ "/Json.beam"),
  {ok, B2} = file:read_file(D2 ++ "/Json.beam"),
  io:format("load1 ~p~n", [code:load_binary('Json', "d1", B1)]),
  io:format("who after load1: ~p~n", ['Json':who()]),
  io:format("load2 ~p (replaces; d1 becomes old code)~n", [code:load_binary('Json', "d2", B2)]),
  io:format("who after load2: ~p; old code present: ~p~n", ['Json':who(), erlang:check_old_code('Json')]),
  io:format("load3 (third, old code not purged) ~p~n", [code:load_binary('Json', "d1", B1)]),
  io:format("soft_purge ~p~n", [code:soft_purge('Json')]).
X
escript c.escript "$T/d1" "$T/d2" 2>&1
echo "=== D: release assembly - two applications that both contain module 'Json'"
for a in a1 a2; do
  mkdir -p $a/ebin; cp $( [ $a = a1 ] && echo d1 || echo d2)/Json.beam $a/ebin/
  cat > $a/ebin/$a.app <<X
{application, $a, [{description,"x"},{vsn,"1"},{modules,['Json']},{registered,[]},{applications,[kernel,stdlib]}]}.
X
done
cat > rel.rel <<'X'
{release,{"rel","1"},{erts,"13.2.2.5"},[{kernel,"8.5.4.2"},{stdlib,"4.3.1.3"},{a1,"1"},{a2,"1"}]}.
X
erl -noshell -pa a1/ebin -pa a2/ebin -eval '
  R = systools:make_script("rel", [silent, {path, ["a1/ebin","a2/ebin"]}]),
  io:format("~p~n", [R]), halt().' 2>&1 | cut -c1-400
rm -rf "$T"
