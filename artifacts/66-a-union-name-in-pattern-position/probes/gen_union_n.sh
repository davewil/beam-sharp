#!/usr/bin/env bash
# Generate scale/N-{dup,union,sig}/ modules: N-member record union C, wider parameter D = C | :none.
#   dup   : one clause per member, bodies duplicated (what exemplar 4 forces today; compiles on stock bsc)
#   union : ONE clause `Handle(C c)` (needs the prototype compiler; refused on stock bsc)
#   sig   : parameter typed C directly, `Handle(c) -> ...` (the plain case, today's best; no :none arm)
# Usage: gen_union_n.sh N OUTROOT
N=$1; R=$2
body='    var a = c.Id * 2
    var b = a + c.Id
    var d = b * b + a
    d + 1'
for v in dup union sig; do
  D=$R/N${N}$v; mkdir -p $D
  f=$D/m.bs
  { echo "module N${N}$v"; echo
    for i in $(seq 1 $N); do echo "record R$i { Id: int }"; done
    members=$(for i in $(seq 1 $N); do printf 'R%s | ' $i; done); members=${members% | }
    echo "type C = $members"; echo "type D = C | :none"; echo
    case $v in
     dup)   echo "public int | :none Handle(D d)"; echo
            for i in $(seq 1 $N); do echo "Handle(R$i c) ->"; echo "$body"; done
            echo "Handle(:none) -> :none";;
     union) echo "public int | :none Handle(D d)"; echo
            echo "Handle(C c) ->"; echo "$body"; echo "Handle(:none) -> :none";;
     sig)   echo "public int Handle(C c)"; echo
            echo "Handle(c) ->"; echo "$body";;
    esac; } > $f
done
