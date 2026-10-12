#!/usr/bin/env bash
# Probe 64/02 - option<T> declared generically and INSTANTIATED at term/atom through a type variable.
# Does F31's declaration-site refusal see it? What does the caller's type become? What happens at run time?
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
echo "git HEAD: $(git -C $REPO log --oneline -1)"
W=$(mktemp -d); trap 'rm -rf $W' EXIT
mkdir -p $W/Gen; cat > $W/Gen/Gen.bs <<'B'
module Gen

// A generic "first element" - option<T> with T a quantified variable.
public option<T> Head<T>(list<T> xs)
Head([])        -> :nothing
Head([x, ..r])  -> x

// Instantiations by the CALLER at three element types.
public option<int> AtInt(list<int> xs)
AtInt(xs) -> Head(xs)

public term AtTerm(list<term> xs)
AtTerm(xs) -> Head(xs)

public atom AtAtom(list<atom> xs)
AtAtom(xs) -> Head(xs)
B
echo "=== source ==="; cat $W/Gen/Gen.bs
echo; echo "=== bsc --api ==="; "$BSC" --api $W/Gen 2>&1
echo; echo "=== compile ==="; "$BSC" -o $W/out $W/Gen 2>&1; echo "exit=$?"
echo; echo "=== run: Head([]) vs Head([:nothing]) at term and atom ==="
for call in "AtTerm []" "AtTerm [:nothing]" "AtAtom []" "AtAtom [:nothing]" "AtInt []" "AtInt [3]"; do
  set -- $call; printf '  %-22s -> ' "$call"; "$BSC" -o $W/out2 $W/Gen "$1" "$2" 2>&1 | tail -1
done
echo
echo "=== a caller that tries to branch on the failure channel of Head at term ==="
mkdir -p $W/Br; cat > $W/Br/Br.bs <<'B'
module Br

public option<T> Head<T>(list<T> xs)
Head([])        -> :nothing
Head([x, ..r])  -> x

public atom Probe(list<term> xs)
Probe(xs) -> Head(xs) switch {
    :nothing => :was_empty,
    v        => :was_value
}
B
cat $W/Br/Br.bs | sed -n 4,20p
"$BSC" -o $W/outb $W/Br 2>&1; echo "exit=$?"
for a in "[]" "[:nothing]" "[1]"; do printf '  Probe %-12s -> ' "$a"; "$BSC" -o $W/outb2 $W/Br Probe "$a" 2>&1 | tail -1; done
echo
echo "=== the ONE emitted body of Head<T> (erased generics: no per-instantiation copy exists to box at term only) ==="
"$BSC" -o $W/outa $W/Gen >/dev/null 2>&1
erl -noshell -eval '{ok,Fs}=file:consult(hd(init:get_plain_arguments())), [io:put_chars(erl_pp:form(F)) || F <- Fs, element(1,F)==function orelse element(1,F)==attribute andalso element(3,F)==spec, case F of {function,_,N,_,_} -> N==(list_to_atom("Head")); {attribute,_,spec,{{N,_},_}} -> N==(list_to_atom("Head")); _ -> false end], halt().' -extra $W/outa/Gen.abstr
