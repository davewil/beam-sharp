#!/usr/bin/env bash
# Scratch-copy patch: the record TAG test is emitted on exported functions only (the 18 §4 reading). $1 = scratch build dir.
python3 - "$1/src/bs_emit.erl" <<'P'
import sys
p=sys.argv[1]; s=open(p).read()
old="""        {ok, Tag} ->
            case constrains_kind(Pat) of"""
new="""        {ok, _} when not Public -> {Pat, []};
        {ok, Tag} ->
            case constrains_kind(Pat) of"""
assert s.count(old)==1; open(p,'w').write(s.replace(old,new))
P
