#!/usr/bin/env bash
# Regenerates option_b.patch: a PROTOTYPE of the path rule (Option B) against a scratch copy of
# compiler/src. The repo's compiler is not touched. Output: option_b.patch (unified diff).
set -e
cd "$(dirname "$0")"; ROOT=$(cd ../../.. && pwd)
W=/tmp/optb-src; rm -rf $W; mkdir -p $W/a $W/b; cp $ROOT/compiler/src/*.erl $ROOT/compiler/src/*.xrl $ROOT/compiler/src/*.yrl $W/a/; cp $W/a/* $W/b/
python3 - "$W/b" <<'PY'
import sys
d=sys.argv[1]
p=d+"/bs_check.erl"; s=open(p).read()
old="""        true  -> add_module_import(M, World, Acc);
        false ->"""
new="""        true  -> may_name(L, M, Self),
                 add_module_import(M, World, Acc);
        false ->"""
assert old in s; s=s.replace(old,new)
old2="                {Children, _} -> add_namespace_import(M, Children, Acc)"
new2="""                {Children, _} ->
                    add_namespace_import(
                      M, [C || C <- Children, allowed(Self, C)], Acc)"""
assert old2 in s; s=s.replace(old2,new2)
old3="%% Local names take precedence over imports at `unqualified_key/4`.\nadd_module_import"
new3='''%% OPTION B PROTOTYPE. A module whose path has an `Internal` segment may be named only by a
%% module rooted at that segment's parent (Go's `internal/` rule). The LAST such segment wins.
internal_parent(M) ->
    Segs = string:split(atom_to_list(M), ".", all),
    case [I || {I, "Internal"} <- lists:zip(lists:seq(1, length(Segs)), Segs)] of
        []  -> none;
        Is  -> lists:sublist(Segs, lists:last(Is) - 1)
    end.

allowed(Self, M) ->
    case internal_parent(M) of
        none   -> true;
        Parent -> lists:prefix(Parent, string:split(atom_to_list(Self), ".", all))
    end.

may_name(L, M, Self) ->
    case allowed(Self, M) of
        true  -> ok;
        false -> erlang:error({internal_module, M, Self,
                               string:join(internal_parent(M), "."), L})
    end.

%% Local names take precedence over imports at `unqualified_key/4`.
add_module_import'''
assert old3 in s; s=s.replace(old3,new3)
open(p,"w").write(s)
p=d+"/bs_diag.erl"; s=open(p).read()
old="built(Path, {unknown_module, Mod, Line}) ->"
new="""built(Path, {internal_module, Mod, Self, Parent, Line}) ->
    #{tag => internal_module, severity => error, file => Path, line => Line,
      module => Mod, caller => Self, parent => Parent};
built(Path, {unknown_module, Mod, Line}) ->"""
assert old in s; s=s.replace(old,new,1)
old="message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->"
new="""message(#{tag := internal_module, file := P, line := L, column := C, module := Mod,
          caller := Self, parent := Parent}) ->
    {"~s:~p:~p: error: ~s cannot name ~s~n"
     "  a module under an `Internal` directory may be named only by modules under ~s.~n",
     [P, L, C, Self, Mod, Parent]};
message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->"""
assert old in s; s=s.replace(old,new,1)
open(p,"w").write(s)
PY
(cd $W && diff -u a/bs_check.erl b/bs_check.erl; diff -u a/bs_diag.erl b/bs_diag.erl) > option_b.patch || true
wc -l option_b.patch; grep -c '^+[^+]' option_b.patch
