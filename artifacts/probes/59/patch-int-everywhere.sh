#!/usr/bin/env bash
# Scratch-copy patch: the int/float KIND test is emitted on private functions too (tag-test scope). $1 = scratch build dir.
python3 - "$1/src/bs_emit.erl" <<'P'
import sys
p=sys.argv[1]; s=open(p).read()
old="""        none when Public ->
            case kind_only(TypeExpr, Ctx) of"""
new="""        none ->
            case kind_only(TypeExpr, Ctx) of"""
assert s.count(old)==1; s=s.replace(old,new)
old2="""                _     -> int_guard(Pat, TypeExpr, Accept, I, Line, Ctx)
            end;
        none ->
            {Pat, []}
    end."""
new2="""                _     -> int_guard(Pat, TypeExpr, Accept, I, Line, Ctx)
            end
    end."""
assert s.count(old2)==1; open(p,'w').write(s.replace(old2,new2))
P
