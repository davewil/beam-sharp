#!/usr/bin/env bash
# Third SCRATCH build: the OTP-25 build PLUS a ~25-line PROTOTYPE of Option 2's compiler delta:
# at the one place a generic call is instantiated (bs_check:checked_call_typed/7, the `subst_tpl(RetT, Sub)`
# line) refuse a union member that the substitution makes absorbed.  Bare minimum: no new text beyond one
# message clause; a member that substitutes to `none` is exempt so `Head([])` is not refused.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$("$HERE/build-bsc-otp25.sh" | tail -1)"; BASE_WS="$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "$BASE")")")")")"
WS="${BSC_WS_CALLSITE:-/tmp/claude-0/ws64-callsite}"
if [ ! -x "$WS/compiler/_build/default/bin/bsc" ]; then
  rm -rf "$WS"; mkdir -p "$WS"; cp -r "$BASE_WS/compiler" "$WS/compiler"; cd "$WS/compiler"
  python3 - <<'PY'
p='src/bs_check.erl'; s=open(p).read()
old="""            {subst_tpl(RetT, Sub),
             poly_arg_diags(L, Shown, Args, ATys, Ps, Inst, C) ++ D, ATys};"""
new="""            {subst_tpl(RetT, Sub),
             [{error, L, C#ctx.fname, {collapsed_instantiation, Shown, bs_types:to_string(M), bs_types:to_string(O)}}
              || {M, O} <- inst_collapsed(RetT, Sub)] ++
             poly_arg_diags(L, Shown, Args, ATys, Ps, Inst, C) ++ D, ATys};"""
assert old in s; s=s.replace(old,new)
old2="%% Type arguments needing no expectation first, at the template's extent."
new2="""%% PROTOTYPE (ticket 64 probe): a returned union whose member the substitution absorbs.
inst_collapsed({t_union, Ms}, Sub) ->
    Inst = [subst_tpl(M, Sub) || M <- Ms],
    [{M, bs_types:union(Rest)}
     || {I, M} <- lists:zip(lists:seq(1, length(Inst)), Inst),
        Rest <- [[X || {J, X} <- lists:zip(lists:seq(1, length(Inst)), Inst), J =/= I]],
        Rest =/= [],
        not bs_types:is_subtype(M, bs_types:none()),
        absorbed(M, bs_types:union(Rest))];
inst_collapsed(_, _) -> [].

""" + old2
assert old2 in s; s=s.replace(old2,new2,1)
open(p,'w').write(s)
p='src/bs_diag.erl'; s=open(p).read()
old="""built(Path, {Sev, Line, Fn, {validate_over_arrow, Ty}}) ->"""
new="""built(Path, {Sev, Line, Fn, {collapsed_instantiation, Callee, M, O}}) ->
    (at(Sev, Path, Line, Fn))#{tag => collapsed_instantiation, callee => Callee, member => M, absorber => O};
""" + old
assert old in s; s=s.replace(old,new,1)
old="""message(#{tag := instantiation_conflict, file := P, line := L, column := C, function := Fn,
          callee := Callee, type_variable := Var, lower_argument := Pos,"""
new="""message(#{tag := collapsed_instantiation, file := P, line := L, column := C, function := Fn,
          callee := Callee, member := M, absorber := O}) ->
    {"~s:~p:~p: error: ~s calls ~s at a type where `~s` is absorbed by `~s`~n"
     "  the union it returns has one member at this instantiation, so no caller~n"
     "  can tell the success value from the marker. Tag the result.~n",
     [P, L, C, Fn, Callee, M, O]};
""" + old
assert old in s; s=s.replace(old,new,1)
open(p,'w').write(s)
PY
  rebar3 escriptize >"$WS/build.log" 2>&1 || { cat "$WS/build.log"; exit 1; }
fi
echo "$WS/compiler/_build/default/bin/bsc"
