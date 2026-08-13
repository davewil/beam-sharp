#!/usr/bin/env bash
# 29f — what SPARK proves statically about an Ada predicate, and what it defers to run time.
#
# Closes gap [g3] of research/29. This is the evidence ticket 20's amendment B rests on: SPARK
# is the only system surveyed that both permits *arbitrary* user predicates and proves some of
# them at compile time. If it discharges them statically, Ada's permissiveness is not merely
# "permit and check later".
#
# Three questions:
#   1. Which predicate checks does GNATprove prove, and which does it leave as "might fail"?
#      Each subtype below appears twice — once with a precondition that entails the predicate,
#      once with nothing known about the argument.
#   2. Is SPARK's line the same as Ada's syntactic `predicate-static` line? 29c measured that
#      `Odd mod 2 = 1` is refused Ada's static tier on *form* while `Pos > 0` is admitted, at
#      identical cost. Both appear here. If SPARK treats them alike, the two lines are
#      different — which is what research/29 §1.2's containment finding predicts.
#   3. Where does the obligation land — the callee, or the conversion at the call site?
#      `Consume (X : Odd)` is called from two procedures with different contracts.
#
# HOW THIS RUNS, AND WHY NOT IN DOCKER. GNATprove is packaged in no Debian suite (the `spark`
# package is SPARK 2005). It installs as an Alire crate, and the crate manifest publishes
# **x86-64 builds only** — Windows, macOS and Linux x86-64, and no aarch64 build of any kind:
#   https://raw.githubusercontent.com/alire-project/alire-index/stable-1.3.0/index/gn/gnatprove/gnatprove-12.1.1.toml
# The Linux x86-64 build (FSF 16.1.0) needs glibc >= 2.38, so it will not run on Debian 12, and
# Debian 13 amd64 containers do not start at all on this machine — a bare
# `docker run --platform linux/amd64 debian:13 echo` hangs indefinitely, where the same command
# on debian:12 returns instantly. See [g3] in research/29.
#
# So this uses the **macOS x86-64 build under Rosetta 2**, which needs no container. One prover
# is unusable — alt-ergo wants an x86_64 libgmp that an arm64 Homebrew does not provide — so the
# run is restricted to cvc4 and z3, both of which the bundle ships working.
#
# Usage:  ./29f_spark_proves_predicates.sh
# Needs:  macOS on Apple Silicon with Rosetta 2, or any x86-64 host. ~194 MB download, cached.

set -u

VER=12.1.0-1
CACHE=${GNATPROVE_CACHE:-${TMPDIR:-/tmp}/beam-sharp-gnatprove}
PREFIX="$CACHE/gnatprove-x86_64-darwin-$VER"
URL="https://github.com/alire-project/GNAT-FSF-builds/releases/download/gnatprove-$VER/gnatprove-x86_64-darwin-$VER.tar.gz"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script fetches the macOS x86-64 build. On Linux x86-64, swap URL/PREFIX for the"
  echo "linux build in the same release and it should work unchanged."
  exit 2
fi
if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
  echo "Rosetta 2 is not available; cannot run the x86-64 toolchain. No aarch64 build exists."
  exit 2
fi

if [ ! -x "$PREFIX/bin/gnatprove" ]; then
  echo "--- fetching GNATprove $VER (~194 MB) into $CACHE"
  mkdir -p "$CACHE"
  curl -sSL --max-time 900 -o "$CACHE/gp.tar.gz" "$URL" || { echo "download failed"; exit 1; }
  tar xzf "$CACHE/gp.tar.gz" -C "$CACHE" || { echo "extract failed"; exit 1; }
fi

export PATH="$PREFIX/bin:$PATH"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/p.gpr" <<'GPR'
project P is
   for Source_Dirs use (".");
   for Object_Dir use "obj";
end P;
GPR

cat > "$WORK/probe.ads" <<'ADA'
package Probe with SPARK_Mode is

   --  A *constraint*. Ada raises Constraint_Error, not Assertion_Error (29c §3).
   subtype Small is Integer range 1 .. 10;

   --  A predicate Ada refuses its static tier on FORM (29c §2: "expression is not
   --  predicate-static"), though it costs one machine operation.
   subtype Odd is Integer with Dynamic_Predicate => Odd mod 2 = 1;

   --  A predicate Ada DOES admit to the static tier, at the same cost.
   subtype Pos is Integer with Static_Predicate => Pos > 0;

   --  An O(n) predicate over the value's content: the analogue of ticket 20's
   --  `binary where valid_utf8`, and the shape amendment B is really about.
   function All_Upper (S : String) return Boolean
     with Post => All_Upper'Result = (for all I in S'Range => S (I) in 'A' .. 'Z');

   subtype Shouty is String with Dynamic_Predicate => All_Upper (Shouty);

   ---------------------------------------------------------------------------
   -- 1 and 2. Each tier, with and without an entailing precondition
   ---------------------------------------------------------------------------
   function Small_Ok   (X : Integer) return Small with Pre => X in 1 .. 5;
   function Small_Bad  (X : Integer) return Small;

   function Odd_Ok     (X : Integer) return Odd   with Pre => X mod 2 = 1;
   function Odd_Bad    (X : Integer) return Odd;

   function Pos_Ok     (X : Integer) return Pos   with Pre => X > 0;
   function Pos_Bad    (X : Integer) return Pos;

   function Shouty_Ok  (S : String) return Shouty
     with Pre => (for all I in S'Range => S (I) in 'A' .. 'Z');
   function Shouty_Bad (S : String) return Shouty;

   ---------------------------------------------------------------------------
   -- 3. Where does the obligation land?
   ---------------------------------------------------------------------------
   procedure Consume (X : Odd);                --  the callee declares the predicate
   procedure Call_Site_Ok  (X : Integer) with Pre => X mod 2 = 1;
   procedure Call_Site_Bad (X : Integer);      --  nothing known about X

end Probe;
ADA

cat > "$WORK/probe.adb" <<'ADA'
package body Probe with SPARK_Mode is

   function All_Upper (S : String) return Boolean is
   begin
      for I in S'Range loop
         if S (I) not in 'A' .. 'Z' then
            return False;
         end if;
         pragma Loop_Invariant (for all J in S'First .. I => S (J) in 'A' .. 'Z');
      end loop;
      return True;
   end All_Upper;

   function Small_Ok   (X : Integer) return Small  is (Small (X));
   function Small_Bad  (X : Integer) return Small  is (Small (X));
   function Odd_Ok     (X : Integer) return Odd    is (Odd (X));
   function Odd_Bad    (X : Integer) return Odd    is (Odd (X));
   function Pos_Ok     (X : Integer) return Pos    is (Pos (X));
   function Pos_Bad    (X : Integer) return Pos    is (Pos (X));
   function Shouty_Ok  (S : String)  return Shouty is (Shouty (S));
   function Shouty_Bad (S : String)  return Shouty is (Shouty (S));

   procedure Consume (X : Odd) is null;

   procedure Call_Site_Ok  (X : Integer) is begin Consume (Odd (X)); end Call_Site_Ok;
   procedure Call_Site_Bad (X : Integer) is begin Consume (Odd (X)); end Call_Site_Bad;

end Probe;
ADA

echo "=== GNATprove version ==="
gnatprove --version 2>&1 | head -2

echo
echo "=== which bundled provers actually run here ==="
for p in cvc4 z3 alt-ergo; do
  printf '  %-10s ' "$p"
  "$PREFIX/libexec/spark/bin/$p" --version 2>&1 | head -1
done

echo
echo "=== proof results (alt-ergo excluded: no x86_64 libgmp on an arm64 Homebrew) ==="
( cd "$WORK" && gnatprove -P p.gpr --level=2 --report=all --prover=cvc4,z3 2>&1 ) \
  | grep -E "predicate check|range check|postcondition|loop invariant|Phase" \
  | sed 's|^|  |'

echo
echo "  Read the pairs: *_Ok carries a precondition entailing the predicate, *_Bad does not."
echo "  probe.adb lines 14/15 Small, 16/17 Odd, 18/19 Pos, 20/21 Shouty, 25/26 the call sites."
