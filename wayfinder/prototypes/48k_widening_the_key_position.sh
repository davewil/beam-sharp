#!/usr/bin/env bash
# PROTOTYPE 48k — can the key position of the three brace forms be widened,
# and what does yecc NOT tell you about it?
#
# Throwaway. Ticket 48, pricing the sub-question 48i left open.
#
# 48i established that all three brace forms take the single terminal `uident`
# in key position, so a dictionary key — a string, an atom, a number — is
# refused at the parser:
#
#     field_decl   -> uident ':' type_expr     bs_parser.yrl:98    the TYPE
#     pat_field    -> uident ':' pattern       bs_parser.yrl:490   the PATTERN
#     assign_field -> uident '=' expr          bs_parser.yrl:702   construct + `with`
#
# The open question was whether ONE widened form serves both the record and the
# dictionary, or whether a dictionary needs a SECOND form standing beside them.
# This probe prices the parser half of that. It does NOT price the type half —
# `bs_types.erl:99` is a separate wall and 48j names it.
#
# The repo rule is that yecc conflicts are MEASURED, not inferred from a quiet
# build. So every variant is run through `yecc:file/2` with both controls:
#
#   1. RED control   — a deliberate reduce/reduce grammar. Must report > 0.
#   2. GREEN control — the untouched grammar. Must report 0.
#
# And because a conflict count is not the only way a grammar change can be
# wrong, every variant is also PARSED against four snippets, using the shipped
# lexer and a parser generated from the variant itself. That behavioural half is
# the point of the probe: the maximal generalisation measures ZERO conflicts and
# still destroys the PascalCase key that ships today.
#
#   1. Does a bounded `map_key` (name | string | atom | integer) conflict?
#   2. Does the inline shape — literals per rule, no shared nonterminal — differ?
#   3. Does the maximal generalisation (key becomes `pattern`) conflict?
#   4. Does any variant BREAK the shipped PascalCase key?
#
#   ./48k_widening_the_key_position.sh
#
# Requires: OTP 28, a built bsc (for bs_lexer). Run from anywhere; resolves the
# repo itself. Runs in a temp dir and deletes nothing in the tree.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../.."
GRAMMAR="$ROOT/compiler/src/bs_parser.yrl"
EBIN="$ROOT/compiler/_build/default/lib/bsc/ebin"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[ -f "$GRAMMAR" ] || { echo "no grammar at $GRAMMAR"; exit 2; }
[ -f "$EBIN/bs_lexer.beam" ] || { echo "no built lexer at $EBIN — run rebar3 escriptize"; exit 2; }

# ---------------------------------------------------------------------------
# The four snippets. Two are controls in their own right: PASCAL must parse in
# every variant that claims to be backwards compatible, and STRING is the whole
# point of the exercise.
# ---------------------------------------------------------------------------
cat > "$WORK/pascal.bs" <<'EOF'
module T

record Order { Status: int }

public int Read(Order o)

Read({ Status: s }) -> s
EOF

cat > "$WORK/string.bs" <<'EOF'
module T

public int Read(term o)

Read({ "acme": s }) -> s
EOF

cat > "$WORK/atomkey.bs" <<'EOF'
module T

public int Read(term o)

Read({ :acme: s }) -> s
EOF

cat > "$WORK/typedecl.bs" <<'EOF'
module T

type Assigns = { "acme": int }

public int Read(Assigns a)

Read(a) -> 1
EOF

# ---------------------------------------------------------------------------
# Grammar patching. Exact-string replacement, and a miss is fatal — a variant
# that silently failed to apply measures the pristine grammar and looks clean.
# ---------------------------------------------------------------------------
patch () { # file before after
  python3 - "$1" "$2" "$3" <<'PY'
import sys
path, before, after = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
if src.count(before) != 1:
    sys.stderr.write("PATCH MISS (%d occurrences): %.60s\n" % (src.count(before), before))
    sys.exit(3)
open(path, "w").write(src.replace(before, after))
PY
}

TYPE_RULE="field_decl -> uident ':' type_expr : {field, value('\$1'), '\$3'}."
PAT_RULE="pat_field -> uident ':' pattern : {value('\$1'), '\$3'}."
ASSIGN_RULE="assign_field -> uident '=' expr : {value('\$1'), '\$3'}."

add_nonterminal () { # file name
  patch "$1" \
    '  switch_arms switch_arm modpath using_decl visibility call' \
    "  switch_arms switch_arm modpath using_decl visibility call
  $2"
}

add_rules () { # file rules
  patch "$1" 'Erlang code.' "$2
Erlang code."
}

# ---------------------------------------------------------------------------
# Measure one grammar: conflicts, then behaviour on all four snippets.
# ---------------------------------------------------------------------------
measure () { # yrl label
  local yrl="$1" label="$2" log="$WORK/$2.log"
  erl -noshell -pa "$EBIN" -eval "
    Yrl = \"$yrl\",
    case yecc:file(Yrl, [{report, true}, {verbose, false}, {return, true}]) of
      {ok, F, _Ws} ->
        case compile:file(F, [binary, return_errors]) of
          {ok, M, B} ->
            {module, M} = code:load_binary(M, F, B),
            P = fun(File) ->
                  {ok, Src} = file:read_file(File),
                  case bs_lexer:string(binary_to_list(Src)) of
                    {ok, Ts, _} -> case M:parse(Ts) of
                                     {ok, _}    -> \"ok   \";
                                     {error, _} -> \"SYNTAX\"
                                   end;
                    _ -> \"lexerr\"
                  end
                end,
            io:format(\"BEHAVIOUR ~s ~s ~s ~s~n\",
                      [P(\"$WORK/pascal.bs\"), P(\"$WORK/string.bs\"),
                       P(\"$WORK/atomkey.bs\"), P(\"$WORK/typedecl.bs\")]);
          {error, Es, _} -> io:format(\"BEHAVIOUR compile-error ~p~n\", [Es])
        end;
      {error, Es, _} -> io:format(\"YECC_ERROR ~p~n\", [Es])
    end, halt(0)." > "$log" 2>&1

  local summary sr rr total behaviour
  summary=$(grep -oE 'conflicts: [0-9]+ shift/reduce, [0-9]+ reduce/reduce' "$log" | head -1 || true)
  sr=$(printf '%s' "${summary:-}" | grep -oE '[0-9]+ shift/reduce' | grep -oE '[0-9]+' || echo 0)
  rr=$(printf '%s' "${summary:-}" | grep -oE '[0-9]+ reduce/reduce' | grep -oE '[0-9]+' || echo 0)
  total=$(( ${sr:-0} + ${rr:-0} ))
  behaviour=$(grep '^BEHAVIOUR' "$log" | head -1 | sed 's/^BEHAVIOUR //' || true)
  [ -z "$behaviour" ] && behaviour="(no parser built)"
  printf '  %-22s  sr=%-3s rr=%-3s  |  %s\n' "$label" "${sr:-0}" "${rr:-0}" "$behaviour"
  echo "$total" > "$WORK/$label.total"
}

echo "════════════════════════════════════════════════════════════════════════"
echo " 48k — widening the brace key position"
echo "════════════════════════════════════════════════════════════════════════"
echo
echo "  behaviour columns:   PascalCase  string-key  atom-key  type-decl"
echo "  'ok' = parses, 'SYNTAX' = refused at the parser."
echo

# --- §1. Controls, first, both directions -----------------------------------
echo "─── §1  CONTROLS — the harness must be able to see a conflict ───"
cp "$GRAMMAR" "$WORK/pristine.yrl"
measure "$WORK/pristine.yrl" "GREEN pristine"

cp "$GRAMMAR" "$WORK/red.yrl"
add_nonterminal "$WORK/red.yrl" "rr_control" || exit 3
add_rules "$WORK/red.yrl" "rr_control -> lident : {p_var, 0, value('\$1')}.
pattern -> rr_control : '\$1'." || exit 3
measure "$WORK/red.yrl" "RED  rr-control"

GREEN=$(cat "$WORK/'GREEN pristine'.total" 2>/dev/null || cat "$WORK/GREEN pristine.total")
RED=$(cat "$WORK/RED  rr-control.total")
echo
if [ "$GREEN" -ne 0 ]; then
  echo "  ✗ SELF-TEST FAILED: the untouched grammar reports $GREEN conflicts."
  exit 1
fi
if [ "$RED" -le 0 ]; then
  echo "  ✗ SELF-TEST FAILED: the deliberate reduce/reduce grammar reported none."
  echo "    The harness cannot see conflicts, so every 0 below is worthless."
  exit 1
fi
echo "  ✓ self-test passed: pristine = 0, deliberate defect = $RED. The harness can see conflicts."
echo

# --- §2. Shape A — a shared bounded map_key nonterminal ----------------------
echo "─── §2  SHAPE A — a shared, BOUNDED map_key nonterminal ───"
KEYRULES="map_key -> uident     : {k_name, value('\$1')}.
map_key -> string_lit : {k_lit,  value('\$1')}.
map_key -> atom_lit   : {k_lit,  value('\$1')}.
map_key -> integer    : {k_lit,  value('\$1')}."

shape_a () { # label wantType wantPat wantAssign
  local out="$WORK/a_$1.yrl"
  cp "$GRAMMAR" "$out"
  add_nonterminal "$out" "map_key" || exit 3
  add_rules "$out" "$KEYRULES" || exit 3
  [ "$2" = 1 ] && { patch "$out" "$TYPE_RULE"   "field_decl -> map_key ':' type_expr : {field, '\$1', '\$3'}." || exit 3; }
  [ "$3" = 1 ] && { patch "$out" "$PAT_RULE"    "pat_field -> map_key ':' pattern : {'\$1', '\$3'}." || exit 3; }
  [ "$4" = 1 ] && { patch "$out" "$ASSIGN_RULE" "assign_field -> map_key '=' expr : {'\$1', '\$3'}." || exit 3; }
  measure "$out" "$1"
}
shape_a "A declared-unused" 0 0 0
shape_a "A widen-TYPE"      1 0 0
shape_a "A widen-PATTERN"   0 1 0
shape_a "A widen-ASSIGN"    0 0 1
shape_a "A widen-ALL"       1 1 1
echo

# --- §3. Shape B — inline alternatives, no shared nonterminal ---------------
echo "─── §3  SHAPE B — literals inlined per rule, no shared nonterminal ───"
cp "$GRAMMAR" "$WORK/b_all.yrl"
patch "$WORK/b_all.yrl" "$TYPE_RULE" "$TYPE_RULE
field_decl -> string_lit ':' type_expr : {field, value('\$1'), '\$3'}.
field_decl -> atom_lit ':' type_expr : {field, value('\$1'), '\$3'}.
field_decl -> integer ':' type_expr : {field, value('\$1'), '\$3'}." || exit 3
patch "$WORK/b_all.yrl" "$PAT_RULE" "$PAT_RULE
pat_field -> string_lit ':' pattern : {value('\$1'), '\$3'}.
pat_field -> atom_lit ':' pattern : {value('\$1'), '\$3'}.
pat_field -> integer ':' pattern : {value('\$1'), '\$3'}." || exit 3
patch "$WORK/b_all.yrl" "$ASSIGN_RULE" "$ASSIGN_RULE
assign_field -> string_lit '=' expr : {value('\$1'), '\$3'}.
assign_field -> atom_lit '=' expr : {value('\$1'), '\$3'}.
assign_field -> integer '=' expr : {value('\$1'), '\$3'}." || exit 3
measure "$WORK/b_all.yrl" "B inline-ALL"
echo

# --- §4. Shape C — the MAXIMAL generalisation -------------------------------
echo "─── §4  SHAPE C — the maximal generalisation: key becomes the value's own nonterminal ───"
cp "$GRAMMAR" "$WORK/c_pat.yrl"
patch "$WORK/c_pat.yrl" "$PAT_RULE" "pat_field -> pattern ':' pattern : {'\$1', '\$3'}." || exit 3
measure "$WORK/c_pat.yrl" "C key=pattern"
echo

# --- §5. The verdict --------------------------------------------------------
echo "════════════════════════════════════════════════════════════════════════"
A_ALL=$(cat "$WORK/A widen-ALL.total")
C_PAT=$(cat "$WORK/C key=pattern.total")
C_BEHAVIOUR=$(grep '^BEHAVIOUR' "$WORK/C key=pattern.log" | head -1)

echo " Shape A (bounded map_key), all three positions: $A_ALL conflicts."
echo " Shape C (key = pattern):                        $C_PAT conflicts."
echo
case "$C_BEHAVIOUR" in
  *"SYNTAX"*)
    echo " AND YET — shape C's behaviour line is:"
    echo "   $C_BEHAVIOUR"
    echo
    echo " The FIRST column is the PascalCase key that ships today. Shape C"
    echo " refuses it, because there is no bare 'pattern -> uident' in the"
    echo " grammar: widening the key to 'pattern' REMOVES the form that works."
    echo
    echo " Both shapes measure zero conflicts. They are not equivalent. A"
    echo " conflict count cannot see a regression, so it is not the measurement"
    echo " that decides this question."
    ;;
  *)
    echo " Shape C did not refuse the PascalCase key — re-read the behaviour line:"
    echo "   $C_BEHAVIOUR"
    ;;
esac
echo "════════════════════════════════════════════════════════════════════════"
