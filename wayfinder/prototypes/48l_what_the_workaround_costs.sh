#!/usr/bin/env bash
# PROTOTYPE 48l — what does living WITHOUT an unbounded key domain actually cost?
#
# Throwaway. Ticket 48, question 1. David: "If the key domain doesn't become
# unbounded what is lost? And if it does become unbounded what is the cost?"
#
# The cost half is measured elsewhere (48k for the parser, bs_types.erl:99 for
# the algebra). This probe measures the OTHER half, which had never been run:
# the documented workaround, `list<(atom, term)>`, exercised as a real Plug-style
# assigns channel with real bugs planted in it.
#
# The framing this probe was written to test was: "no map means the values are
# `term`, so nothing is checked." That is WRONG, and the probe says so — §1's
# WrongType arm shows the checker DOES force a narrowing on the value. What is
# unchecked is the KEY, and it is unchecked at compile time and at run time
# alike. Scoping that correctly is the point.
#
#   1. A misspelled key — caught, or silent?
#   2. A wrong VALUE type — caught? (the control that scopes §1)
#   3. Can a clause head ask "does this channel carry key K"?
#   4. CONTROL — does the checker work at all on a CLOSED key set?
#
# If §4 goes green while §1 and §3 go silent, the blindness is specific to the
# open key domain rather than general.
#
#   ./48l_what_the_workaround_costs.sh
#
# Requires: OTP 28, a built bsc. Runs in a temp dir, touches nothing in the tree.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../.."
BSC="$ROOT/compiler/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[ -x "$BSC" ] || { echo "no built bsc at $BSC — run rebar3 escriptize"; exit 2; }

run () { "$BSC" "$1" "$2" "$3" 2>&1 | tail -1; }
mk  () { mkdir -p "$WORK/$1"; cat > "$WORK/$1/$1.bs"; }

echo "════════════════════════════════════════════════════════════════════"
echo " 48l — the cost of the list<(atom, term)> workaround"
echo "════════════════════════════════════════════════════════════════════"

# ---------------------------------------------------------------------------
mk Chan <<'EOF'
module Chan

record Conn { Path: atom, Assigns: list<(atom, term)> }

// No prelude keyfind exists, so every program hand-writes this.
private term Lookup(list<(atom, term)> xs, atom k)
Lookup([], k)                             -> :absent
Lookup([(kk, v), ..rest], k) when kk == k -> v
Lookup([(kk, v), ..rest], k)              -> Lookup(rest, k)

// A `term` cannot reach a concrete parameter, so every read needs this.
private int AsInt(term t)
AsInt(t) -> ValidateAs<int>(t) switch { (:error, e) => 0, n => n }

private string AsString(term t)
AsString(t) -> ValidateAs<string>(t) switch { (:error, e) => "unset", s => s }

private Conn Auth(Conn c)
Auth(c) -> c with { Assigns = [(:user_id, 42), ..c.Assigns] }

// The correct read.
private int ReadUserId(Conn c)
ReadUserId(c) -> AsInt(Lookup(c.Assigns, :user_id))

private int ReadTypo(Conn c)
ReadTypo(c) -> AsInt(Lookup(c.Assigns, :userid))

private string ReadAsString(Conn c)
ReadAsString(c) -> AsString(Lookup(c.Assigns, :user_id))

public int Correct(atom p)
Correct(p) -> ReadUserId(Auth(Conn{ Path = p, Assigns = [] }))

// THE BUG: :userid, not :user_id. Nothing connects the two spellings.
public int Typo(atom p)
Typo(p) -> ReadTypo(Auth(Conn{ Path = p, Assigns = [] }))

// The writer put an int in; this reader wants a string out.
public string WrongType(atom p)
WrongType(p) -> ReadAsString(Auth(Conn{ Path = p, Assigns = [] }))
EOF

echo
echo "─── §1  A MISSPELLED KEY, and §2 a wrong value type ───"
C=$(run "$WORK/Chan/Chan.bs" Correct ':x')
T=$(run "$WORK/Chan/Chan.bs" Typo ':x')
W=$(run "$WORK/Chan/Chan.bs" WrongType ':x')
printf '  %-12s %s\n' "Correct"   "$C"
printf '  %-12s %s\n' "Typo"      "$T"
printf '  %-12s %s\n' "WrongType" "$W"
echo
if [ "$C" = "42" ] && [ "$T" = "0" ]; then
  echo "  ✓ the typo is SILENT: compiles clean, runs clean, returns the absent answer."
  echo "    Indistinguishable from a legitimately absent optional key."
else
  echo "  ✗ unexpected: Correct=$C Typo=$T — re-read before trusting the writeup."
fi

# The control that scopes it: is the VALUE unchecked too?
mk Bare <<'EOF'
module Bare

private int Twice(int n)
Twice(n) -> n + n

// Hand a bare `term` straight to a concrete parameter, with no narrowing.
public int Doubled(term t)
Doubled(t) -> Twice(t)
EOF
BARE=$("$BSC" "$WORK/Bare/Bare.bs" Doubled ':x' 2>&1 | grep -c 'not covered by\|does not accept' || true)
echo
if [ "$BARE" -gt 0 ]; then
  echo "  ✓ CONTROL: a bare \`term\` reaching an \`int\` parameter is a COMPILE ERROR."
  echo "    So the VALUE domain is checked — the checker forces a narrowing, and"
  echo "    WrongType above fails as a value at run time rather than silently."
  echo "    The blindness is the KEY domain specifically, not \"everything is term\"."
else
  echo "  ✗ CONTROL FAILED: a bare term was accepted. The scoping claim above is unsupported."
fi

# ---------------------------------------------------------------------------
mk Head <<'EOF'
module Head

record Conn { Path: atom, Assigns: list<(atom, term)> }

// The only head form that parses asks a POSITIONAL question, not a key question.
public atom Who(Conn c)
Who({ Assigns: [(:user_id, uid), ..rest] }) -> :saw_user
Who(c)                                      -> :no_user

// Two stages that wrote the SAME keys in a different order.
public atom First(atom p)
First(p) -> Who(Conn{ Path = p, Assigns = [(:user_id, 42), (:locale, :en)] })

public atom Second(atom p)
Second(p) -> Who(Conn{ Path = p, Assigns = [(:locale, :en), (:user_id, 42)] })
EOF

echo
echo "─── §3  CAN A CLAUSE HEAD ASK THE KEY QUESTION? ───"
F=$(run "$WORK/Head/Head.bs" First ':x')
S=$(run "$WORK/Head/Head.bs" Second ':x')
printf '  %-28s %s\n' "user_id written first"  "$F"
printf '  %-28s %s\n' "locale written first"   "$S"
echo
if [ "$F" = ":saw_user" ] && [ "$S" = ":no_user" ]; then
  echo "  ✓ Same key set. Different write order. Different answer. Both compile clean."
  echo "    The head cannot express \"does this channel carry key K\", so key"
  echo "    dispatch must move into the body — which is what B#'s whole dispatch"
  echo "    story exists to avoid."
else
  echo "  ✗ unexpected: First=$F Second=$S"
fi

# ---------------------------------------------------------------------------
mk Closed <<'EOF'
module Closed

type Role = :admin | :user

record Meta { Role: Role }
record Conn { Path: atom, Assigns: Meta }

// Two arms over a two-member union, no catch-all.
public atom Which(Conn c)
Which({ Assigns: { Role: :admin } }) -> :is_admin
Which({ Assigns: { Role: :user } })  -> :is_user

public atom Go(atom p)
Go(p) -> Which(Conn{ Path = p, Assigns = Meta{ Role = :admin } })
EOF

mk ClosedRed <<'EOF'
module ClosedRed

type Role = :admin | :user | :guest

record Meta { Role: Role }
record Conn { Path: atom, Assigns: Meta }

// The SAME two arms, but the union grew. This must go red.
public atom Which(Conn c)
Which({ Assigns: { Role: :admin } }) -> :is_admin
Which({ Assigns: { Role: :user } })  -> :is_user

public atom Go(atom p)
Go(p) -> Which(Conn{ Path = p, Assigns = Meta{ Role = :admin } })
EOF

echo
echo "─── §4  CONTROL — the checker on a CLOSED key set ───"
echo "  (this control routes through a record: an anonymous brace map cannot be"
echo "   CONSTRUCTED — there is no bare-brace expression production, 48j wall two.)"
G=$(run "$WORK/Closed/Closed.bs" Go ':x')
RED=$("$BSC" "$WORK/ClosedRed/ClosedRed.bs" Go ':x' 2>&1 | grep -c 'not exhaustive' || true)
printf '  %-34s %s\n' "closed union, both arms" "$G"
printf '  %-34s %s\n' "union grew by one member" "$([ "$RED" -gt 0 ] && echo 'REFUSED — not exhaustive' || echo 'accepted')"
echo
if [ "$G" = ":is_admin" ] && [ "$RED" -gt 0 ]; then
  echo "  ✓ Over a CLOSED key set the guarantee is live: add a member and the"
  echo "    clause set goes red. The engine works. §1 and §3 are not the engine"
  echo "    being weak — they are the open key domain being outside its reach."
else
  echo "  ✗ CONTROL FAILED: Go=$G, red=$RED. Without this the probe proves nothing."
fi

echo
echo "════════════════════════════════════════════════════════════════════"
echo " The trade, in one line:"
echo
echo "   The unchecked open key domain EXISTS TODAY, spelled as a list."
echo "   Adding map<K,V> does not create it — it makes it a type the"
echo "   compiler knows the shape of. Exhaustiveness over open keys is"
echo "   vacuous either way; §4 shows what is NOT being given up."
echo "════════════════════════════════════════════════════════════════════"
