#!/usr/bin/env bash
# Regenerates option_c.patch: PROTOTYPE of Option C (a callee-side `friend Mod` declaration)
# against a scratch copy of compiler/src. The repo's compiler is not touched.
set -e
cd "$(dirname "$0")"; ROOT=$(cd ../../.. && pwd)
W=/tmp/optc-src; rm -rf $W; mkdir -p $W/a $W/b; cp $ROOT/compiler/src/*.erl $ROOT/compiler/src/*.xrl $ROOT/compiler/src/*.yrl $W/a/; cp $W/a/* $W/b/
python3 - "$W/b" <<'PY'
import sys
d=sys.argv[1]
def sub(p, old, new, count=1):
    s=open(p).read(); assert old in s, (p, old); open(p,"w").write(s.replace(old,new,count))
sub(d+"/bs_lexer.xrl", "behaviour               : {token, {'behaviour', TokenLoc}}.",
    "friend                  : {token, {'friend', TokenLoc}}.\nbehaviour               : {token, {'behaviour', TokenLoc}}.")
sub(d+"/bs_parser.yrl", "  behaviour_decl record_decl", "  friend_decl behaviour_decl record_decl")
sub(d+"/bs_parser.yrl", "'using' 'behaviour' 'record'", "'using' 'behaviour' 'friend' 'record'")
sub(d+"/bs_parser.yrl", "decl -> behaviour_decl : '$1'.", "decl -> behaviour_decl : '$1'.\ndecl -> friend_decl : '$1'.")
sub(d+"/bs_parser.yrl", "behaviour_decl -> 'behaviour' uident :",
    "friend_decl -> 'friend' modpath : {friend, line('$1'), modatom('$2')}.\nbehaviour_decl -> 'behaviour' uident :")
sub(d+"/bsc.erl", "                                     behaviours => [B || {behaviour, _, B} <- Decls],\n                                     %% The module's `record`",
    "                                     behaviours => [B || {behaviour, _, B} <- Decls],\n                                     friends => [F || {friend, _, F} <- Decls],\n                                     %% The module's `record`")
p=d+"/bs_check.erl"
sub(p, """        true  -> add_module_import(M, World, Acc);
        false ->""", """        true  -> may_name(L, M, Self, World),
                 add_module_import(M, World, Acc);
        false ->""")
sub(p, "                {Children, _} -> add_namespace_import(M, Children, Acc)",
"""                {Children, _} ->
                    add_namespace_import(
                      M, [C || C <- Children, allowed(Self, C, World)], Acc)""")
sub(p, "%% Local names take precedence over imports at `unqualified_key/4`.\nadd_module_import",
'''%% OPTION C PROTOTYPE. A module with no `friend` line is open. With one or more, a caller must
%% sit at or under one of the named modules.
allowed(Self, M, World) ->
    case maps:get(friends, maps:get(M, World, #{}), []) of
        []      -> true;
        Friends -> Mine = string:split(atom_to_list(Self), ".", all),
                   lists:any(fun(F) -> lists:prefix(string:split(atom_to_list(F), ".", all), Mine) end,
                             Friends)
    end.

may_name(L, M, Self, World) ->
    case allowed(Self, M, World) of
        true  -> ok;
        false -> erlang:error({friend_module, M, Self, maps:get(friends, maps:get(M, World)), L})
    end.

%% Local names take precedence over imports at `unqualified_key/4`.
add_module_import''')
p=d+"/bs_diag.erl"
sub(p, "built(Path, {unknown_module, Mod, Line}) ->", """built(Path, {friend_module, Mod, Self, Friends, Line}) ->
    #{tag => friend_module, severity => error, file => Path, line => Line,
      module => Mod, caller => Self, friends => Friends};
built(Path, {unknown_module, Mod, Line}) ->""")
sub(p, "message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->", """message(#{tag := friend_module, file := P, line := L, column := C, module := Mod,
          caller := Self, friends := Fs}) ->
    {"~s:~p:~p: error: ~s cannot name ~s~n"
     "  ~s declares `friend ~s`, so only those modules and the modules under them may.~n",
     [P, L, C, Self, Mod, Mod, lists:join(", ", [atom_to_list(F) || F <- Fs])]};
message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->""")
PY
(cd $W && diff -u a/bs_check.erl b/bs_check.erl; diff -u a/bs_diag.erl b/bs_diag.erl; diff -u a/bsc.erl b/bsc.erl; diff -u a/bs_lexer.xrl b/bs_lexer.xrl; diff -u a/bs_parser.yrl b/bs_parser.yrl) > option_c.patch || true
echo "added lines: $(grep -c '^+[^+]' option_c.patch)  removed: $(grep -c '^-[^-]' option_c.patch)"
