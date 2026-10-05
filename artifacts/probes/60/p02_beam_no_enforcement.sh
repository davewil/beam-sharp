#!/usr/bin/env bash
# CLAIM (ticket 60 / ticket 18 section 1): the BEAM has one entry label per function, exported
# or not; it cannot enforce *who* may call an exported function, so "who may name" is
# either a compile-time check on the caller or nothing.
# REFUTED IF: an exported function of one module cannot be called from an unrelated module
# (static, variable-module, or apply), OR the ExpT of a beam carries anything but {F,A,Label}.
. "$(dirname "$0")/lib.sh"
D="$WORK/p02"; rm -rf "${D:?}"; mkdir -p "$D"
erlc -o "$D" "$HERE"/erl/callee.erl "$HERE"/erl/stranger.erl || exit 1
cd "$D" || exit 1
run() { erl -noshell -pa "$D" -eval "$1" -s init stop; }
echo '--- static literal call from an unrelated module'
run 'io:format("~p~n", [stranger:static(1)]).'
echo '--- variable module/function (M:F(A))'
run 'io:format("~p~n", [stranger:dynamic(callee, f, 2)]).'
echo '--- apply/3 with atoms built at run time'
run 'io:format("~p~n", [stranger:via_apply(3)]).'
echo '--- the non-exported function from outside: the only thing the VM refuses'
run 'io:format("~p~n", [catch callee:hidden(1)]).'
echo '--- a bsc-emitted beam is the same: public function callable from a hand-written Erlang module'
B=$(build_variant base >/dev/null 2>&1; bsc_of base)
[ -x "$B" ] || { build_variant base; B=$(bsc_of base); }
(cd "$HERE/fixtures/shop" && "$B" --src-root . -o "$D" Shop/Internal) || exit 1
run 'io:format("~p~n", [stranger:dynamic(list_to_atom("Shop.Internal"), list_to_atom("RecomputeTotal"), [4,5,6])]).'
echo '--- ExpT (export table) of that beam: the only per-function visibility fact a beam carries'
run '{ok,{_,[{exports,E}]}} = beam_lib:chunks("'"$D"'/Shop.Internal.beam",[exports]), io:format("~p~n",[E]).'
echo '--- chunk ids present in the beam (looking for any caller-restricted export record)'
run 'L = beam_lib:info("'"$D"'/Shop.Internal.beam"), io:format("~p~n",[[Id || {Id,_,_} <- proplists:get_value(chunks, L)]]).'
# mechanical verdict: all three call styles returned the callee's tuple/number
out_static=$(run 'io:format("~p", [stranger:static(1)]).')
out_dyn=$(run 'io:format("~p", [stranger:dynamic(callee, f, 2)]).')
out_apply=$(run 'io:format("~p", [stranger:via_apply(3)]).')
[ "$out_static" = "{f,1,2}" ] && [ "$out_dyn" = "{f,2,3}" ] && [ "$out_apply" = "{f,3,4}" ]
verdict "beam-cannot-restrict-callers-of-an-exported-function" $?
