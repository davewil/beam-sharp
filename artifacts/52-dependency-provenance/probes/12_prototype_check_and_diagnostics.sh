#!/bin/sh
# What would the compile-time check print? A prototype pass (prov_check.erl) over the AST of the
# patched grammar (probe 10), run on real fixtures. The pass is NOT in bsc; this is what it would say.
. "$(dirname "$0")/env.sh"
here=$(cd "$(dirname "$0")" && pwd)
[ -f $W/proto/a/bs_parser.beam ] || "$here/10_grammar_delta.sh" >/dev/null 2>&1
erlc -o $W $here/prov_check.erl
GOOD=$W/greeter_build/dev/lib:$W/rlib_src/_build/default/lib
mkdir -p $W/orphan
cat > $W/p12.escript <<'E'
#!/usr/bin/env escript
main([Mode, Variant, File]) ->
    true = code:add_patha("/tmp/p52"), true = code:add_patha("/tmp/p52/orphan"),
    true = code:add_patha("/tmp/p52/proto/" ++ Variant),
    {ok, Bin} = file:read_file(File),
    {ok, Toks, _} = bs_lexer:string(binary_to_list(Bin)),
    {ok, Ds} = bs_parser:parse(Toks),
    Out = prov_check:run(list_to_atom(Mode), File, Ds),
    case Out of [] -> io:format("  (no diagnostics)~n"); _ -> [io:format("~ts", [O]) || O <- Out] end.
E
cd $W/proto
mk() { # name, body
  printf '%s\n' "$2" > $1.bs; }
mk a_ok 'module Net
using :'"'"'Elixir.Greeter'"'"' from :greeter {
    binary hello(binary name)
}
using :'"'"'Elixir.Greeter.Extra'"'"' from :greeter {
    binary shout(binary name)
}
using :lists {
    int sum(list<int> xs)
}'
sed 's/Greeter.Extra/Greeter.Nope/' a_ok.bs > a_typo.bs
sed "0,/from :greeter/s//from :kernel/" a_ok.bs > a_wrongapp.bs
sed "0,/ from :greeter/s///" a_ok.bs > a_nofrom.bs
mk a_noapp 'module Net
using :'"'"'Greet'"'"' from :orphan {
    binary hi(binary name)
}'
mk b_ok 'module Net
requires :greeter
using :'"'"'Elixir.Greeter'"'"' {
    binary hello(binary name)
}
using :'"'"'Elixir.Greeter.Extra'"'"' {
    binary shout(binary name)
}'
mk b_norequires 'module Net
using :'"'"'Elixir.Greeter'"'"' {
    binary hello(binary name)
}'
mk b_unused 'module Net
requires :greeter
requires :rlib
using :'"'"'Elixir.Greeter'"'"' {
    binary hello(binary name)
}'
mk c_ok 'module Net
using :'"'"'Elixir.Greeter'"'"' {
    binary hello(binary name)
}'
run() { echo "-- $1"; ERL_LIBS="$5" escript $W/p12.escript $2 $3 $6; }
echo "=== Option A: per-block  using :X from :app"
run "all present"                 a a "ERL_LIBS=good"  "$GOOD" a_ok.bs
run "ERL_LIBS has no greeter"     a a "ERL_LIBS=other" "$W/other_libs" a_ok.bs
run "module typo, app present"    a a "ERL_LIBS=good"  "$GOOD" a_typo.bs
run "module claimed from wrong app (kernel)" a a x "$GOOD" a_wrongapp.bs
run "non-OTP module, no from"     a a "ERL_LIBS=good"  "$GOOD" a_nofrom.bs
run "module in a -pa dir, no app" a a x "$GOOD" a_noapp.bs
echo "=== Option B: per-module  requires :app"
run "all present"                 b b "ERL_LIBS=good"  "$GOOD" b_ok.bs
run "using without requires"      b b "ERL_LIBS=good"  "$GOOD" b_norequires.bs
run "requires never used"         b b "ERL_LIBS=good"  "$GOOD" b_unused.bs
run "requires, app absent"        b b "ERL_LIBS=other" "$W/other_libs" b_ok.bs
echo "=== Option C: module on path only, nothing new in the source"
run "all present"                 c base "ERL_LIBS=good" "$GOOD" c_ok.bs
run "ERL_LIBS has no greeter"     c base "ERL_LIBS=other" "$W/other_libs" c_ok.bs
