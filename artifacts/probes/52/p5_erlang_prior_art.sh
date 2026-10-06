#!/usr/bin/env bash
# p5 — what does Erlang/OTP 28 itself record and check about application dependencies, and WHEN?
#   E1  the `applications` key of the .app resource file is the declared dependency list (installed source quoted below)
#   E2  systools:make_script (release build time) REFUSES a release that names an application it cannot find; the same call
#       succeeds with ERL_LIBS set (CONTROL) -> Erlang's compile-time-ish check exists, lives in the release tool, and answers per machine
#   E3  application:ensure_all_started (run time) fails with a value, not error:undef, if a declared dep's .app is missing
#   E4  xref (build-time cross-reference) reports `undefined_function_calls` for a call into an absent app -> the closest Erlang analogue
#       to "check at compile time that the module you call exists"; it is a SEPARATE tool, not erlc, and it needs the library on the path
#   E5  erlc itself checks nothing about a remote call (CONTROL for E4: erlc accepts the same caller)
source "$(dirname "$0")/common.sh"; mk_fakelib
LIB=/tmp/claude-0/mm/root/envs/b/lib/erlang/lib
echo "== E1 installed source: what the system treats as the declared dependency list"
grep -n "check_item({_,{applications,Apps}},I)" $LIB/sasl-4.3.2/src/systools_make.erl | sed 's|^|systools_make.erl:|'
grep -n "undefined_applications(Appls) of" $LIB/sasl-4.3.2/src/systools_make.erl | sed 's|^|systools_make.erl:|'
grep -n "format_error({undefined_applications" $LIB/sasl-4.3.2/src/systools_make.erl | sed 's|^|systools_make.erl:|'
grep -n "{'applications', \[Application" $LIB/kernel-10.6.3/src/application.erl | sed 's|^|application.erl:|'
echo "== E2 systools:make_script"
mkdir -p "$WORK/rel"; cat > "$WORK/rel/r.rel" <<'EOT'
{release,{"r","1"},{erts,"16.4"},[{kernel,"10.6.3"},{stdlib,"7.3"},{fakelib,"1.0"}]}.
EOT
EV='R=systools:make_script("r",[silent,no_warn_sasl,{path,["'$WORK'/libs/*/ebin"]}]), io:format("~p",[element(1,R)]), halt().'
EVNOPATH='R=systools:make_script("r",[silent,no_warn_sasl]), io:format("~p",[R]), halt().'
a=$(cd "$WORK/rel" && env -u ERL_LIBS erl -noshell -eval "$EVNOPATH" 2>&1 | head -c 400); echo "fakelib absent : $a"
b=$(cd "$WORK/rel" && ERL_LIBS="$WORK/libs" erl -noshell -eval "$EVNOPATH" 2>&1 | head -c 400); echo "fakelib on ERL_LIBS: $b"
expect "E2 absent -> error value naming the app" "error" "$a"; expect "E2 absent names fakelib" "fakelib" "$a"
expect "E2 control: present -> ok" "ok" "$b"; expect_not "E2 control: present is not an error" "error" "$b"
echo "== E3 run-time: ensure_all_started of an app whose declared dep is missing"
mkdir -p "$WORK/libs3/top-1.0/ebin"
echo '{application,top,[{description,"t"},{vsn,"1.0"},{modules,[]},{registered,[]},{applications,[kernel,stdlib,fakelib]}]}.' > "$WORK/libs3/top-1.0/ebin/top.app"
EV3="io:format(\"~p\",[application:ensure_all_started(top)]),halt()."
c=$(ERL_LIBS="$WORK/libs3" erl -noshell -eval "$EV3" 2>&1 | head -c 300); echo "$c"
expect "E3 a value, naming the missing app's .app file" "fakelib.app" "$c"
d=$(ERL_LIBS="$WORK/libs3:$WORK/libs" erl -noshell -eval "$EV3" 2>&1 | head -c 300); echo "control (both on ERL_LIBS): $d"
expect "E3 control: with fakelib present it starts" "{ok," "$d"
echo "== E4/E5 erlc accepts a caller of an absent module; xref flags it"
cat > "$WORK/erl/caller.erl" <<'EOT'
-module(caller).
-export([go/0]).
go() -> fakelib_mod:hello().
EOT
e=$(erlc +debug_info -o "$WORK/erl" "$WORK/erl/caller.erl" 2>&1); echo "erlc: exit=$? out=[$e]"; expect_empty "E5 erlc says nothing" "$e"
XR='{ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]), xref:set_library_path(s,code_path), {ok,_}=xref:add_module(s,"'$WORK'/erl/caller.beam"), R=xref:analyze(s,undefined_function_calls), io:format("~p",[R]), halt().'
x=$(env -u ERL_LIBS erl -noshell -eval "$XR" 2>&1 | head -c 300); echo "xref (fakelib absent; xref library path set to code_path): $x"
expect "E4 xref names the undefined call" "fakelib_mod" "$x"; expect "E4 ... as an undefined call" "hello" "$x"
x2=$(ERL_LIBS="$WORK/libs" erl -noshell -eval "$XR" 2>&1 | head -c 300); echo "xref (fakelib on ERL_LIBS; xref library path set to code_path): $x2"
expect "E4 control: with the app on the path xref is clean" "{ok,[]}" "$x2"
finish
