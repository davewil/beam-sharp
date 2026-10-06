#!/usr/bin/env bash
# p3 — is "is the application present?" decidable at compile time, and what does the answer depend on?
#   D1  the same question (code:lib_dir(fakelib)) answers differently under two ERL_LIBS: the verdict is a fact about the
#       MACHINE, not about the source
#   D2  module-level and app-level presence can disagree: a dir put on the path with -pa (no lib layout, no .app) loads the
#       module but lib_dir(App) says bad_name -> an app-name check REFUSES a program that runs (ticket 51 measured the
#       "beams copied to a plain directory work identically" case; this is its consequence for a name check)
#   D3  CONTROL: a layout with a .app file AND an ebin is found; one with an ebin and NO .app is also found (lib_dir keys on the
#       directory name, not the .app) -> "present" is not "is a real OTP application"
#   D4  the compile-time check can be answered inside the bsc VM (ERL_LIBS is in effect there) — shown in p5
#   D6  `erlang` (8 of the 18 `using` blocks in compiler/examples) is PRELOADED and belongs to no application: a rule "every
#       `using` names its app" has no app to name for it; the other OTP modules map to kernel/stdlib
#   D7  a STRONGER check than name-only is also decidable per machine: "module M's beam lives under app A's lib dir" -- true for the
#       real pair, FALSE for a wrong pair (lists in ssl), and `erlang` (preloaded) needs a special case
#   D5  module name -> app name is NOT derivable (census below), so the app has to be WRITTEN somewhere
source "$(dirname "$0")/common.sh"; mk_fakelib
q () { erl -noshell -eval "$1" -s init stop; }
echo "== D1 one query, two environments"
a=$(env -u ERL_LIBS erl -noshell -eval 'io:format("~p",[element(1,code:lib_dir(fakelib))]),halt().' 2>&1 | head -c 200)
b=$(ERL_LIBS="$WORK/libs" erl -noshell -eval 'io:format("~s",[filename:basename(code:lib_dir(fakelib))]),halt().' 2>&1)
echo "ERL_LIBS unset      : code:lib_dir(fakelib) -> $a"
echo "ERL_LIBS=\$WORK/libs : code:lib_dir(fakelib) -> $b"
expect "D1 absent -> {error,bad_name}" "error" "$a"; expect "D1 present -> fakelib-1.0" "fakelib-1.0" "$b"
echo "== D2 module present, app absent (plain directory via -pa)"
mkdir -p "$WORK/flat"; cp "$WORK/libs/fakelib-1.0/ebin/fakelib_mod.beam" "$WORK/flat/"
w=$(env -u ERL_LIBS erl -noshell -pa "$WORK/flat" -eval 'io:format("which=~s lib_dir=~p call=~p",[filename:basename(code:which(fakelib_mod)), code:lib_dir(fakelib), fakelib_mod:hello()]),halt().' 2>&1)
echo "$w"
expect "D2 the module loads and runs" "call=42" "$w"; expect "D2 yet the app check says bad_name" "lib_dir={error,bad_name}" "$w"
echo "== D3 what counts as an application directory?"
mkdir -p "$WORK/libs2/noapp-1.0/ebin" "$WORK/libs2/dirmismatch-1.0/ebin"
erlc -o "$WORK/libs2/noapp-1.0/ebin" "$WORK/erl/fakelib_mod.erl"
echo '{application,other_name,[{vsn,"1.0"},{modules,[]},{registered,[]},{applications,[kernel]}]}.' > "$WORK/libs2/dirmismatch-1.0/ebin/other_name.app"
r=$(ERL_LIBS="$WORK/libs2" erl -noshell -eval 'io:format("noapp=~p dirmismatch=~p other_name=~p",[filename:basename(code:lib_dir(noapp)), filename:basename(code:lib_dir(dirmismatch)), code:lib_dir(other_name)]),halt().' 2>&1)
echo "$r"
expect "D3 a dir with ebin and no .app IS reported as an application" "noapp=\"noapp-1.0\"" "$r"
expect "D3 lookup keys on the DIRECTORY name, not the .app's name" "other_name={error,bad_name}" "$r"
echo "== D5 census: is the app derivable from a module name?  (method: read every .app 'modules' list in OTP 28 + Elixir 1.20.4)"
c=$(escript "$PROBES/p3_census.escript" /tmp/claude-0/mm/root/envs/b/lib/erlang/lib /tmp/claude-0/mm/root/envs/b/lib/elixir/lib); echo "$c"
expect "D5 OTP: module name rarely equals app name" "module name == app name: 25 (2.0%)" "$c"
echo "== D6 which application owns each foreign module the shipped examples use?"
EV6="[io:format(\"~-12w get_application=~-16w which=~s~n\",[M, application:get_application(M), case code:which(M) of preloaded -> preloaded; P -> filename:basename(P) end]) || M <- [erlang,lists,maps,ets,file,binary,gen_server,json]], halt()."
o6=$(erl -noshell -eval "$EV6" 2>&1); echo "$o6"
expect "D6 erlang is preloaded, no owning application" "erlang       get_application=undefined" "$o6"
expect "D6 control: lists belongs to stdlib" "lists        get_application={ok,stdlib}" "$o6"
n_all=$(grep -rh "^using :" compiler/examples | wc -l); n_erl=$(grep -rh "^using :erlang" compiler/examples | wc -l)
echo "using :atom blocks in compiler/examples: $n_all, of which :erlang: $n_erl"
echo "the corpus already names a NON-OTP application (exemplar 25d):"
grep -rn "^using :epgsql" compiler/examples/exemplars | sed 's|^|   |'
echo "   code:lib_dir(epgsql) on this machine = $(erl -noshell -eval 'io:format("~p",[code:lib_dir(epgsql)]),halt().')"
echo "== D7 claim check: does module M's beam live under app A's lib dir?"
EV7='In=fun(M,A)-> case code:which(M) of preloaded -> preloaded; P -> case code:lib_dir(A) of {error,_}=E -> E; D -> lists:prefix(D, P) end end end, io:format("lists in stdlib : ~p~nlists in ssl    : ~p~nfakelib_mod in fakelib : ~p~nfakelib_mod in stdlib : ~p~nerlang in erts  : ~p~nlists in nonesuch : ~p~n",[In(lists,stdlib),In(lists,ssl),In(fakelib_mod,fakelib),In(fakelib_mod,stdlib),In(erlang,erts),In(lists,nonesuch)]), halt().'
d7=$(ERL_LIBS="$WORK/libs" erl -noshell -eval "$EV7"); echo "$d7"
expect "D7 true pair holds" "lists in stdlib : true" "$d7"
expect "D7 control: a wrong pair is caught" "lists in ssl    : false" "$d7"
expect "D7 wrong app for a third-party module is caught" "fakelib_mod in stdlib : false" "$d7"
expect "D7 preloaded needs a special case" "erlang in erts  : preloaded" "$d7"
finish
