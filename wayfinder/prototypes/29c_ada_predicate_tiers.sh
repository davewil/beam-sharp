#!/usr/bin/env bash
# 29c — where Ada 2012 actually cuts its two predicate tiers, measured.
#
# Ticket 20 §5 split refinements by whether the predicate is a BEAM guard — that is, by
# what the runtime decides in O(1). Ada 2012 also ships two predicate tiers, and ticket
# 29 asks whether that is the same structure reached independently. The Ada Reference
# Manual says the cut is on the *form* of the predicate expression (ARM 3.2.4(15/3)
# enumerates seven permitted syntactic forms), not on its cost. This measures that, and
# measures what each tier buys and what predicate failure actually does.
#
# The decisive pair is p6/p7: two predicates of identical runtime cost, one rejected from
# the static tier and one accepted, separated by nothing but which operator they use.
#
# Usage:  ./29c_ada_predicate_tiers.sh
# Needs:  docker, network on first run. GNAT 12.2.0 from Debian 12.

set -u
cd "$(dirname "$0")"

IMG=gnat:12
docker build --platform linux/amd64 -q -t "$IMG" - >/dev/null <<'DOCKERFILE'
FROM debian:12
RUN apt-get update -qq && apt-get install -y gnat && rm -rf /var/lib/apt/lists/*
WORKDIR /w
DOCKERFILE

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

gnat() { docker run --rm --platform linux/amd64 -v "$WORK:/w" -w /w "$IMG" bash -c "$1" 2>&1; }

say() { printf '\n--- %s\n' "$1"; }

echo "=== GNAT version ==="
gnat 'gnatmake --version | head -2'

# ---------------------------------------------------------------------------------------
cat > "$WORK/p1.adb" <<'ADA'
with Ada.Text_IO; use Ada.Text_IO;
procedure P1 is
   subtype Even_Digit is Integer range 0 .. 9
     with Static_Predicate => Even_Digit in 0 | 2 | 4 | 6 | 8;
   function Classify (X : Integer) return String is
   begin
      case X is
         when Even_Digit => return "even digit";
         when others     => return "other";
      end case;
   end Classify;
begin
   Put_Line (Classify (4));
end P1;
ADA

cat > "$WORK/p2.adb" <<'ADA'
with Ada.Text_IO; use Ada.Text_IO;
procedure P2 is
   subtype Pos_Even is Integer
     with Dynamic_Predicate => Pos_Even mod 2 = 0;
   function Classify (X : Integer) return String is
   begin
      case X is
         when Pos_Even => return "even";
         when others   => return "other";
      end case;
   end Classify;
begin
   Put_Line (Classify (4));
end P2;
ADA

cat > "$WORK/p3.adb" <<'ADA'
with Ada.Text_IO; use Ada.Text_IO;
procedure P3 is
   subtype Even_Digit is Integer range 0 .. 9
     with Static_Predicate => Even_Digit in 0 | 2 | 4 | 6 | 8;
   --  Deliberately misses 8. Ada checks case coverage against the predicate.
   function F (X : Even_Digit) return Integer is
   begin
      case X is
         when 0 => return 1;
         when 2 => return 2;
         when 4 => return 3;
         when 6 => return 4;
      end case;
   end F;
begin
   Put_Line (Integer'Image (F (0)));
end P3;
ADA

echo
echo "=== 1. What each tier may be used for ==="
say "Static_Predicate subtype as a case alternative"
gnat 'gnatmake -q -gnata p1.adb && echo "    ACCEPTED — compiles"'
say "Dynamic_Predicate subtype as a case alternative"
gnat 'gnatmake -q -gnata p2.adb || true'
say "case over a Static_Predicate subtype, one value missing"
gnat 'gnatmake -q -gnata p3.adb || true'

# ---------------------------------------------------------------------------------------
cat > "$WORK/p6.adb" <<'ADA'
procedure P6 is
   --  O(1) to evaluate: one machine mod and one compare. But `mod` is not among the
   --  predicate-static forms of ARM 3.2.4(15/3), so Ada refuses it the static tier.
   subtype Odd is Integer with Static_Predicate => Odd mod 2 = 1;
   X : Odd := 3;
begin
   null;
end P6;
ADA

cat > "$WORK/p7.adb" <<'ADA'
procedure P7 is
   --  Also O(1): a single comparison against a static expression. This one IS
   --  predicate-static (ARM 3.2.4(19/3)), so identical cost lands on the other tier.
   subtype Positive_Ish is Integer with Static_Predicate => Positive_Ish > 0;
   X : Positive_Ish := 3;
begin
   null;
end P7;
ADA

echo
echo "=== 2. The decisive pair: same cost, opposite tiers ==="
say "Static_Predicate => Odd mod 2 = 1   (O(1))"
gnat 'gnatmake -q -gnata p6.adb || true'
say "Static_Predicate => Positive_Ish > 0   (O(1), same cost)"
gnat 'gnatmake -q -gnata p7.adb && echo "    ACCEPTED — compiles"'

# ---------------------------------------------------------------------------------------
cat > "$WORK/p5.adb" <<'ADA'
with Ada.Text_IO;     use Ada.Text_IO;
with Ada.Exceptions;  use Ada.Exceptions;
with Ada.Command_Line;
procedure P5 is
   --  Argument_Count is 0 at run time but is not a static expression, so GNAT cannot
   --  constant-fold these and every check lands at run time.
   Nonstatic : constant Integer := Ada.Command_Line.Argument_Count;

   --  An O(n) predicate over the value's *content*: the exact analogue of ticket 20's
   --  `binary where valid_utf8`. Ada lets a user declare this.
   function All_Upper (S : String) return Boolean is
   begin
      for C of S loop
         if C not in 'A' .. 'Z' then return False; end if;
      end loop;
      return True;
   end All_Upper;

   subtype Shouty is String  with Dynamic_Predicate => All_Upper (Shouty);
   subtype Small  is Integer range 1 .. 10;                        --  a *constraint*
   subtype Odd    is Integer with Dynamic_Predicate => Odd mod 2 = 1;

   procedure Show (Label : String; P : not null access procedure) is
   begin
      P.all;
      Put_Line (Label & " -> no exception raised");
   exception
      when E : others => Put_Line (Label & " -> " & Exception_Name (E));
   end Show;

   procedure Bad_Shouty is
      Src : constant String := "hello" & Character'Val (65 + Nonstatic);
      X   : constant Shouty := Shouty (Src);
   begin
      Put_Line (X);
   end Bad_Shouty;

   procedure Bad_Range is
      X : constant Small := Small (99 + Nonstatic);
   begin
      Put_Line (Integer'Image (X));
   end Bad_Range;

   procedure Bad_Odd is
      X : constant Odd := Odd (4 + Nonstatic);
   begin
      Put_Line (Integer'Image (X));
   end Bad_Odd;
begin
   Show ("O(n) content predicate, user-declared", Bad_Shouty'Access);
   Show ("range constraint                     ", Bad_Range'Access);
   Show ("O(1) arithmetic predicate            ", Bad_Odd'Access);
end P5;
ADA

echo
echo "=== 3. What failure does, and whether the check is even there ==="
say "compiled with -gnata (assertion policy Check)"
gnat 'rm -f p5 *.o *.ali; gnatmake -q -gnata p5.adb && ./p5'
say "compiled WITHOUT -gnata (GNAT default assertion policy)"
gnat 'rm -f p5 *.o *.ali; gnatmake -q p5.adb && ./p5'

# ---------------------------------------------------------------------------------------
cat > "$WORK/p8.adb" <<'ADA'
with Ada.Text_IO; use Ada.Text_IO;
procedure P8 is
   --  Ticket 09's newtype gap, in a nominal language. A *subtype* confers no identity;
   --  a *derived type* does. beam-sharp has only the first.
   subtype Meters_S is Float range 0.0 .. Float'Last;
   subtype Feet_S   is Float range 0.0 .. Float'Last;

   type Meters_T is new Float range 0.0 .. Float'Last;
   type Feet_T   is new Float range 0.0 .. Float'Last;

   procedure Take_Meters_S (M : Meters_S) is begin Put_Line (Float'Image (Float (M))); end;
   procedure Take_Meters_T (M : Meters_T) is begin Put_Line (Meters_T'Image (M)); end;

   F_S : constant Feet_S := 3.0;
   F_T : constant Feet_T := 3.0;
begin
   Take_Meters_S (F_S);   --  two subtypes of Float: one type, accepted silently
   Take_Meters_T (F_T);   --  two derived types: distinct types, rejected
end P8;
ADA

echo
echo "=== 4. Does a subtype confer type identity? ==="
say "Feet_S -> Meters_S (subtypes) and Feet_T -> Meters_T (derived types)"
gnat 'gnatmake -q -gnata p8.adb || true'
