#!/usr/bin/env python3
"""Prototype patch for ticket 60: `visible_to <Module>` declaration (callee names who may name it)
and the check at add_import/add_module_import. Applied to a SCRATCH COPY of compiler/src only."""
import re, sys, os
d = sys.argv[1]
def sub(path, old, new, count=1):
    p = os.path.join(d, path); s = open(p).read()
    assert old in s, (path, old[:50])
    open(p, 'w').write(s.replace(old, new, count))
# lexer
sub('bs_lexer.xrl', "using                   : {token, {'using', TokenLoc}}.",
    "using                   : {token, {'using', TokenLoc}}.\nvisible_to              : {token, {'visible_to', TokenLoc}}.")
# parser
sub('bs_parser.yrl', "switch_arms switch_arm modpath using_decl visibility call",
    "switch_arms switch_arm modpath using_decl visible_decl visibility call")
sub('bs_parser.yrl', "'module' 'type' 'when' 'using' 'behaviour'", "'module' 'type' 'when' 'using' 'visible_to' 'behaviour'")
sub('bs_parser.yrl', "decl -> using_decl  : '$1'.", "decl -> using_decl  : '$1'.\ndecl -> visible_decl : '$1'.\nvisible_decl -> 'visible_to' modpath : {visible_to, line('$1'), modatom('$2')}.")
# world entry
sub('bsc.erl', "behaviours => [B || {behaviour, _, B} <- Decls],\n                                     %% The module's `record`",
    "behaviours => [B || {behaviour, _, B} <- Decls],\n                                     visible_to => [V || {visible_to, _, V} <- Decls],\n                                     %% The module's `record`")
# check: thread Self + loc into add_module_import
sub('bs_check.erl', "true  -> add_module_import(M, World, Acc);", "true  -> add_module_import(M, L, Self, Mode, World, Acc);")
sub('bs_check.erl', "add_module_import(M, World, Acc) ->\n    Entry = maps:get(M, World),",
"""add_module_import(M, L, Self, Mode, World, Acc) ->
    Entry = maps:get(M, World),
    case {Mode, maps:get(visible_to, Entry, [])} of
        {strict, [_ | _] = Allowed} ->
            Ok = lists:any(fun(A) -> Self =:= A orelse
                                     lists:prefix(atom_to_list(A) ++ ".", atom_to_list(Self)) end,
                           Allowed),
            Ok orelse erlang:error({not_visible_to, M, Self, Allowed, L});
        _ -> ok
    end,
    add_module_import(M, World, Acc).

add_module_import(M, World, Acc) ->
    Entry = maps:get(M, World),""")
# diag
sub('bs_diag.erl', "built(Path, {unknown_module, Mod, Line}) ->",
"""built(Path, {not_visible_to, Mod, Self, Allowed, Line}) ->
    #{tag => not_visible_to, severity => error, file => Path, line => Line,
      module => Mod, importer => Self, allowed => Allowed};
built(Path, {unknown_module, Mod, Line}) ->""")
sub('bs_diag.erl', "message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->",
"""message(#{tag := not_visible_to, file := P, line := L, column := C, module := Mod, importer := Self, allowed := Al}) ->
    {"~s:~p:~p: error: ~s may not name ~s~n"
     "  ~s declares `visible_to` ~s; ~s is not under any of them.~n",
     [P, L, C, Self, Mod, Mod, lists:join(", ", [atom_to_list(A) || A <- Al]), Self]};
message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->""")

sub('bs_check.erl', "{Children, _} -> add_namespace_import(M, Children, Acc)",
"""{Children, _} ->
                    [begin
                         case {Mode, maps:get(visible_to, maps:get(C, World, #{}), [])} of
                             {strict, [_ | _] = Al} ->
                                 Ok = lists:any(fun(A) -> Self =:= A orelse
                                          lists:prefix(atom_to_list(A) ++ ".", atom_to_list(Self)) end, Al),
                                 Ok orelse erlang:error({not_visible_to, C, Self, Al, L});
                             _ -> ok
                         end
                     end || C <- Children],
                    add_namespace_import(M, Children, Acc)""")
