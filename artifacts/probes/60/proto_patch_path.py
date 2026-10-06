#!/usr/bin/env python3
"""Prototype patch C for ticket 60: NO new syntax. A module whose dotted path has a segment
`Internal` may be named only from the subtree rooted at the segment's parent (Go's rule, pkg.go:1473).
Scratch copy of compiler/src only."""
import sys, os
d = sys.argv[1]
def sub(path, old, new):
    p = os.path.join(d, path); s = open(p).read()
    assert old in s, (path, old[:50]); open(p, 'w').write(s.replace(old, new, 1))
sub('bs_check.erl', "true  -> add_module_import(M, World, Acc);",
    "true  -> internal_ok(M, Self, L, Mode), add_module_import(M, World, Acc);")
sub('bs_check.erl', "{Children, _} -> add_namespace_import(M, Children, Acc)",
    "{Children, _} -> [internal_ok(C, Self, L, Mode) || C <- Children], add_namespace_import(M, Children, Acc)")
sub('bs_check.erl', "add_module_import(M, World, Acc) ->",
"""%% Go's rule: the LAST `Internal` segment; the importer must be the parent or under it.
internal_ok(M, Self, L, strict) ->
    Segs = string:split(atom_to_list(M), ".", all),
    case [I || {S, I} <- lists:zip(Segs, lists:seq(1, length(Segs))), S =:= "Internal"] of
        [] -> ok;
        Is ->
            Parent = lists:join(".", lists:sublist(Segs, lists:last(Is) - 1)),
            P = lists:flatten(Parent),
            SelfS = atom_to_list(Self),
            case SelfS =:= P orelse lists:prefix(P ++ ".", SelfS) of
                true  -> ok;
                false -> erlang:error({not_visible_to, M, Self, [list_to_atom(P)], L})
            end
    end;
internal_ok(_, _, _, _) -> ok.

add_module_import(M, World, Acc) ->""")
sub('bs_diag.erl', "built(Path, {unknown_module, Mod, Line}) ->",
"""built(Path, {not_visible_to, Mod, Self, Allowed, Line}) ->
    #{tag => not_visible_to, severity => error, file => Path, line => Line,
      module => Mod, importer => Self, allowed => Allowed};
built(Path, {unknown_module, Mod, Line}) ->""")
sub('bs_diag.erl', "message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->",
"""message(#{tag := not_visible_to, file := P, line := L, column := C, module := Mod, importer := Self, allowed := Al}) ->
    {"~s:~p:~p: error: ~s may not name ~s~n"
     "  an `Internal` module is visible only under ~s.~n",
     [P, L, C, Self, Mod, lists:join(", ", [atom_to_list(A) || A <- Al])]};
message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->""")
