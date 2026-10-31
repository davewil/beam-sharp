#!/usr/bin/env bash
# Probe (iv): may a user type take a built-in type's name on OTP 25 (this machine)?
# The ticket's claim concerns OTP 26 ("permitted a user type to shadow a built-in type name") -- NOT testable here;
# what is tested is OTP 25's behaviour, which is the "reserve" end of the same spectrum, plus the escape hatch
# OTP 25's erl_lint already carries: the `no_auto_import_types` compile option (erl_lint.erl:2984-2985).
# Run: bash p4_otp25_builtin_type_shadow.sh
set -u
T=$(mktemp -d); cd "$T"
erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'
cat > t1.erl <<'X'
-module(t1).
-export([f/1]).
-type map() :: {my, map}.          % redefine built-in map/0
-spec f(map()) -> ok.
f(_) -> ok.
X
echo "=== A: user type with a built-in's name, default options"
erlc t1.erl; echo "exit=$?"
echo "=== B: same, with -compile(no_auto_import_types).  READ: it compiles, but lint says the user type is UNUSED although -spec f(map()) uses the name => the use site still resolved to the built-in (declaration allowed, shadowing not achieved).  Inference from the warning, not a separate test."
sed 's/^-module(t1)./-module(t2).\n-compile(no_auto_import_types)./' t1.erl > t2.erl
erlc t2.erl; echo "exit=$?"
echo "=== C: a type that is NOT built in (control, must compile)"
sed 's/map()/mymap()/g; s/t1/t3/' t1.erl > t3.erl
erlc t3.erl; echo "exit=$?"
echo "=== D: the same type name twice (control: the other error class, redefine_type)"
printf -- '-module(t4).\n-export([]).\n-type mymap() :: a.\n-type mymap() :: b.\n' > t4.erl
erlc t4.erl; echo "exit=$?"
echo "=== E: does the option show up in the installed lint source? (not an assumption)"
grep -n 'no_auto_import_types' /usr/lib/erlang/lib/stdlib-4.3.1.3/src/erl_lint.erl | head -3
rm -rf "$T"
