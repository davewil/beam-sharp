#!/usr/bin/env python3
"""Prototype patch B for ticket 60: the CALLER declares what it may not name (`forbids <Module>`),
read from the importer's own declarations. Scratch copy of compiler/src only."""
import sys, os
d = sys.argv[1]
def sub(path, old, new):
    p = os.path.join(d, path); s = open(p).read()
    assert old in s, (path, old[:50]); open(p, 'w').write(s.replace(old, new, 1))
sub('bs_lexer.xrl', "using                   : {token, {'using', TokenLoc}}.",
    "using                   : {token, {'using', TokenLoc}}.\nforbids                 : {token, {'forbids', TokenLoc}}.")
sub('bs_parser.yrl', "switch_arms switch_arm modpath using_decl visibility call",
    "switch_arms switch_arm modpath using_decl forbid_decl visibility call")
sub('bs_parser.yrl', "'module' 'type' 'when' 'using' 'behaviour'", "'module' 'type' 'when' 'using' 'forbids' 'behaviour'")
sub('bs_parser.yrl', "decl -> using_decl  : '$1'.", "decl -> using_decl  : '$1'.\ndecl -> forbid_decl : '$1'.\nforbid_decl -> 'forbids' modpath : {forbids, line('$1'), modatom('$2')}.")
# check inside import_env, which already holds Decls and Self: no World field, no bsc.erl change
sub('bs_check.erl', "    Imports = [{L, M} || {import, L, M} <- Decls],\n    Known = maps:keys(World),",
"""    Imports = [{L, M} || {import, L, M} <- Decls],
    Forbids = [F || {forbids, _, F} <- Decls],
    [case lists:any(fun(F) -> M =:= F orelse lists:prefix(atom_to_list(F) ++ ".", atom_to_list(M)) end, Forbids) of
         true when Mode =:= strict -> erlang:error({forbidden_import, Self, M, L});
         _ -> ok
     end || {L, M} <- Imports],
    Known = maps:keys(World),""")
sub('bs_diag.erl', "built(Path, {unknown_module, Mod, Line}) ->",
"""built(Path, {forbidden_import, Self, Mod, Line}) ->
    #{tag => forbidden_import, severity => error, file => Path, line => Line,
      module => Mod, importer => Self};
built(Path, {unknown_module, Mod, Line}) ->""")
sub('bs_diag.erl', "message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->",
"""message(#{tag := forbidden_import, file := P, line := L, column := C, module := Mod, importer := Self}) ->
    {"~s:~p:~p: error: ~s `forbids` ~s, which it names~n", [P, L, C, Self, Mod]};
message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->""")
