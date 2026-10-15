#!/usr/bin/env bash
# Verifier probe V1: does F3's silent generic collapse extend beyond option<T> (R2)?  Variants:
#  G_RES   result<T, atom> Wrap<T>(T)            called at T=term     (brief says check must cover result too, F3 only measured option)
#  G_ATOM  option<T> Wrap<T>(T)                  called at T=atom     (absorbing, non-term)
#  G_REC   record Box<T>{V: option<T>} instantiated at term (written position, generic record)
#  G_EXP   explicit Wrap<term>(t) type argument syntax, if accepted
#  G_CTRL  same as R2 at T=int (control, must be accepted and print 1 for Use 5)
. /home/user/beam-sharp/artifacts/probes/env.sh
W=$(bs_scratch); trap 'rm -rf "$W"' EXIT
mk() { mkdir -p "$W/$1"; cat > "$W/$1/m.bs"; }
run() { echo "== $1: $2"; mkdir -p "$W/o$1"; $BSC -o "$W/o$1" "$W/$1" "${@:3}" 2>&1 | sed "s#$W/##g" | head -6; }
mk G_RES <<'E'
module G_RES

public result<T, atom> Wrap<T>(T x)
Wrap(x) -> x

public int Use(term t)
Use(t) -> Wrap(t) switch { (:error, e) => 0, v => 1 }
E
run G_RES "result<T,atom> generic at T=term, Use((:error,:x)) a PRESENT 2-tuple" Use "(:error, :x)"
mk G_ATOM <<'E'
module G_ATOM

public option<T> Wrap<T>(T x)
Wrap(x) -> x

public int Use(atom t)
Use(t) -> Wrap(t) switch { :nothing => 0, v => 1 }
E
run G_ATOM "option<T> generic at T=atom" Use :nothing
mk G_REC <<'E'
module G_REC

record Box<T> { V: option<T> }

public Box<term> Make(term t)
Make(t) -> Box { V: t }
E
run G_REC "generic record with option<T> field at T=term"
mk G_CTRL <<'E'
module G_CTRL

public option<T> Wrap<T>(T x)
Wrap(x) -> x

public int Use(int t)
Use(t) -> Wrap(t) switch { :nothing => 0, v => 1 }
E
run G_CTRL "control T=int" Use 5
echo "-- stock bsc rc/version:"; $BSC --help 2>&1 | head -2
