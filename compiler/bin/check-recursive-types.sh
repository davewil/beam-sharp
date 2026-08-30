#!/usr/bin/env bash
#
# RECURSIVE TYPES RESOLVE, AND THE NON-CONTRACTIVE ONES STILL DO NOT.
#
# THIS GATE IS A STOPWATCH, NOT A REJECTION TEST, and that is the one design
# decision in it. Every other gate in this directory asserts that some input
# produces some output. The characteristic failure of recursive types produces
# NO output: the checker walks a regular tree forever. F6 learned this the
# expensive way -- a cyclic alias did not error on master, it HUNG, and took the
# rest of that eunit run with it under a `Failed: 0` summary. A hang is
# invisible to a green suite, so every compile here runs under a wall-clock
# budget and a compile that exceeds it is red.
#
# A BUDGET, NOT A HANG DETECTOR. A memoised walk is fast and an unmemoised one
# is not slow, it is infinite -- so any budget discriminates and a generous one
# is fine. `timeout(1)` is not on macOS; `perl -e 'alarm N; exec @ARGV'` is.
#
# WHY THE CONTROL IS NOT OPTIONAL. Ticket 09 §3 requires recursion to pass
# through a type constructor. A definition that does is CONTRACTIVE and denotes
# a real regular tree; one that does not is meaningless and always will be:
#
#     type X = X | int                         not contractive -- permanent error
#     type Tree = :leaf | (:node, Tree, Tree)  contractive -- a feature
#
# An implementation that simply STOPPED REFUSING would pass every positive probe
# here and admit a type describing no values. R6 is that control, and R6b is its
# parametric twin -- the split must survive substitution, not just hold at a
# ground declaration.
#
# WHY R5 CARRIES A USE SITE. Measured 2026-08-30: a parametric alias is stored
# as an unresolved template and resolved PER USE SITE, so a module that declares
# `type T<X> = (X, list<T<X>>)` and never writes `T<int>` compiles today and
# always did. A probe without a use site asserts an absence against a program
# the checker never looked at -- this repo's oldest recurring defect.
#
# WHY R4 AND R7 ARE SEPARATE PROBES. They are the two plausible-but-wrong
# implementations, and each passes the others:
#
#   R4  mutual recursion. Neither `A` nor `B` alone is a cycle; the pair is. A
#       binder keyed on the name currently being resolved handles R1 and fails
#       this one. The spec names this trap explicitly.
#   R7  equirecursive. Two spellings of one type must be interchangeable with no
#       conversion. A NOMINAL binder -- one that decides equality by name --
#       passes R1 through R5 and fails only here, and what shipped would be
#       isorecursive, which is not what ticket 09 decided.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# Generous on purpose: see the header. An unmemoised walk does not take 12s, it
# never finishes.
BUDGET="${BS_RECURSIVE_BUDGET:-12}"

NOT_BUILT="is a recursive type, and those are not built yet"
NON_CONTRACTIVE_1="is defined in terms of itself, and the"
NON_CONTRACTIVE_2="recursion does not pass through a constructor"
NON_CONTRACTIVE_3="not a missing feature"

# ---------------------------------------------------------------------------
# judge -- the whole of the gate's opinion, in one place, so --self-test drives
# THIS code path against fixtures rather than a copy of it. Each probe leaves
# two files: `<P>.out` (combined output) and `<P>.st` (`ok`, `hung`, or `rcN`).
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" p st

  # --- the stopwatch, over every probe including the controls -------------
  for p in R1 R2 R3 R4 R5 R6 R6b R7 R8 R9 R10; do
    st="$(cat "$dir/$p.st")"
    if [ "$st" = "hung" ]; then
      echo "$p: exceeded the ${BUDGET}s budget -- the walk did not terminate. This is the failure the gate exists for: an unmemoised walk over a regular tree is not slow, it is infinite."
    fi
  done

  # --- the positives: these must COMPILE and RUN --------------------------
  check_ok() {
    local p="$1" want="$2" desc="$3" out
    out="$(cat "$dir/$p.out")"
    [ "$(cat "$dir/$p.st")" = "hung" ] && return 0   # already reported above
    case "$out" in
      *"$NOT_BUILT"*)
        echo "$p: $desc -- still refused as an unbuilt feature" ;;
      *)
        if [ "$out" != "$want" ]; then
          echo "$p: $desc -- expected '$want', got '$out'"
        fi ;;
    esac
  }

  check_ok R1 "2"  "a recursive type, two clauses, no catch-all"
  check_ok R2 ":ok" "the iodata shape, nested -- 25e's front wall"
  check_ok R3 ":ok" "recursion through a record field"
  check_ok R4 ":ok" "MUTUAL recursion -- a binder keyed on the name being resolved fails exactly here"
  check_ok R5 ":ok" "recursion under a type parameter, USED at two instantiations"
  check_ok R7 ":ok" "EQUIRECURSIVE -- two spellings are one type; a nominal binder fails exactly here"
  check_ok R9 "(:node, :leaf, (:node, :leaf, :leaf))" "ValidateAs over a recursive type terminates AND round-trips a nested value (F18's owed obligation)"
  check_ok R10 ":ok" "recursion through a BARE LIST, matched -- no tuple anywhere, and the shape that hung"

  # --- R8: the residual is computed, names `:leaf`, and RETURNS ------------
  local r8
  r8="$(cat "$dir/R8.out")"
  if [ "$(cat "$dir/R8.st")" != "hung" ]; then
    case "$r8" in
      *":leaf"*) ;;
      *) echo "R8: a missing clause over a recursive type must name \`:leaf\` in the residual (got '$r8') -- exhaustiveness that terminates but reports nothing is the same defect one step later" ;;
    esac
  fi

  # --- R6 / R6b: THE CONTROLS. These must still be REFUSED -----------------
  local r6 r6b
  r6="$(cat "$dir/R6.out")"
  r6b="$(cat "$dir/R6b.out")"
  case "$r6" in
    *"$NON_CONTRACTIVE_1"*)
      case "$r6" in
        *"$NON_CONTRACTIVE_2"*)
          case "$r6" in
            *"$NON_CONTRACTIVE_3"*) ;;
            *) echo "R6: the non-contractive refusal lost its \"$NON_CONTRACTIVE_3\" half -- the message must keep saying this is permanent, not pending" ;;
          esac ;;
        *) echo "R6: the non-contractive refusal no longer names the constructor rule (got '$r6')" ;;
      esac ;;
    *"$NOT_BUILT"*)
      echo "R6: \`type X = X | int\` is reported as an UNBUILT FEATURE. It is not one -- it describes no set of values and never will. The two refusals have been merged." ;;
    *)
      echo "R6: \`type X = X | int\` was ACCEPTED (got '$r6'). This is the unsound implementation: it passes every positive probe and admits a type with no inhabitants." ;;
  esac
  case "$r6b" in
    *"$NON_CONTRACTIVE_2"*) ;;
    *) echo "R6b: the parametric twin \`type Y<X> = Y<X> | int\` was not refused at its use site (got '$r6b') -- the contractive split must survive substitution" ;;
  esac
}

# ---------------------------------------------------------------------------
# probe -- one directory per module, because a module is a directory here.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1" name rc out

  mk() {
    local n="$1" src="$2"
    mkdir -p "$dir/$n"
    printf '%s' "$src" > "$dir/$n/$n.bs"
  }

  # Runs bsc under the budget. Records `ok`, `hung`, or `rcN`, and the output.
  # `alarm` kills with SIGALRM -> 142 through the shell, 14 raw.
  shot() {
    local p="$1" n="$2"; shift 2
    set +e
    out="$(perl -e 'alarm shift; exec @ARGV' "$BUDGET" "$BSC" "$dir/$n/$n.bs" "$@" 2>&1)"
    rc=$?
    set -e
    printf '%s' "$out" > "$dir/$p.out"
    if [ "$rc" -eq 142 ] || [ "$rc" -eq 14 ]; then
      printf 'hung' > "$dir/$p.st"
    elif [ "$rc" -eq 0 ]; then
      printf 'ok' > "$dir/$p.st"
    else
      printf 'rc%s' "$rc" > "$dir/$p.st"
    fi
  }

  # R1 -- exhaustive over a recursive type, TWO clauses and no catch-all. If
  # `:leaf` and the node tuple did not partition `Tree`, this feature would have
  # bought a type the exhaustiveness checker cannot see through.
  mk R1 'module R1

type Tree = :leaf | (:node, Tree, Tree)

public int Size(Tree t)
Size(:leaf)         -> 0
Size((:node, l, r)) -> 1 + Size(l) + Size(r)
'
  shot R1 R1 Size '(:node, :leaf, (:node, :leaf, :leaf))'

  # R2 -- the iodata shape. NESTED on purpose: a flat literal already compiles
  # as `list<binary>` and would prove nothing.
  # `Render` is the point of this probe as much as `Page` is. A recursive type
  # in a RETURN position is only ever built; one in a PARAMETER is MATCHED, and
  # matching is what drives the subtraction that has to terminate. The first
  # draft declared `Iodata` only as a return type and went green over a compiler
  # that hung on `Render` -- an absence asserted against a program the checker
  # never looked at, in the exact shape this gate exists for.
  mk R2 'module R2

type Iodata = binary | list<Iodata>

public Iodata Page(string title)
Page(t) -> ["<html>", ["<h1>", t, "</h1>"], "</html>"]

public :ok Render(Iodata d)
Render(d) -> :ok

public :ok Go(int n)
Go(n) -> :ok
'
  shot R2 R2 Go 1

  # R3 -- a field is a constructor crossing, and it is the crossing kind with
  # the least in common with a tuple or a list.
  mk R3 'module R3

record Node { Value: int, Kids: list<Node> }

public :ok Go(Node n)
Go(n) -> :ok
'
  shot R3 R3 Go '#{value => 1, kids => []}'

  # R4 -- mutual. Neither name alone is a cycle; the pair is.
  mk R4 'module R4

type A = :nil | (:a, B)
type B = :nil | (:b, A)

public :ok Go(A a)
Go(a) -> :ok
'
  shot R4 R4 Go 'nil'

  # R5 -- under a type parameter, and USED at two instantiations. Polymorphic
  # recursion is PERMITTED: ticket 09's generics answer says so, and ticket 04
  # paid for it with mandatory signatures. The use sites are the point.
  mk R5 'module R5

type Tree<T> = (T, list<Tree<T>>)

public :ok Go(Tree<int> a, Tree<string> b)
Go(a, b) -> :ok
'
  shot R5 R5 Go '(1, [])' '("x", [])'

  # R6 -- THE CONTROL. Not contractive, and must stay refused with today's
  # wording.
  mk R6 'module R6

type X = X | int

public int Go(int n)
Go(n) -> n
'
  shot R6 R6 Go 1

  # R6b -- the parametric twin of the control. Refused at the USE site.
  mk R6b 'module R6b

type Y<X> = Y<X> | int

public int Go(Y<int> y)
Go(y) -> 1
'
  shot R6b R6b Go 1

  # R7 -- EQUIRECURSIVE. `L2` unfolds `L1` one extra level; they denote the same
  # set, so a value of one is accepted where the other is declared with no
  # conversion. Ticket 09's "two names over the same set are the same type",
  # reaching the case that needs coinduction to decide. If this fails, what
  # shipped is isorecursive and 09 was not implemented.
  mk R7 'module R7

type L1 = :nil | (:cons, int, L1)
type L2 = :nil | (:cons, int, :nil | (:cons, int, L2))

public L2 Widen(L1 x)
Widen(x) -> x

public :ok Go(int n)
Go(n) -> :ok
'
  shot R7 R7 Go 1

  # R8 -- exhaustiveness terminates AND the residual is finite. `Size(:leaf)` is
  # deleted, so the diagnostic must name `:leaf` and RETURN. The subtraction
  # that computes a residual walks the type; over a regular tree it must memoise
  # or it unfolds forever. Asserted with a clock as well as a message.
  mk R8 'module R8

type Tree = :leaf | (:node, Tree, Tree)

public int Size(Tree t)
Size((:node, l, r)) -> 1 + Size(l) + Size(r)
'
  shot R8 R8 Size '{node,leaf,leaf}'

  # R9 -- F18's owed obligation, written down in that feature before this one
  # existed: the memo table must hold the function name for a type WHILE that
  # type is still being generated, or the generator recurses into itself.
  # R9 -- F18's owed obligation, written down in that feature before this one
  # existed: the memo table must hold the function name for a type WHILE that
  # type is still being generated, or the generator recurses into itself.
  #
  # THE FIRST DRAFT OF THIS PROBE DECLARED `Tree` AND NEVER CALLED
  # `ValidateAs<Tree>`, so it asserted nothing about the validator at all and
  # went green over a generator that crashed on a binder. The round trip below
  # is the assertion: a NESTED value has to survive, which it can only do if the
  # generated validator calls itself.
  mk R9 'module R9

type Tree = :leaf | (:node, Tree, Tree)

public result<Tree, ValidationError> Check(term t)
Check(t) -> ValidateAs<Tree>(t)
'
  shot R9 R9 Check '(:node, :leaf, (:node, :leaf, :leaf))'

  # R10 -- RECURSION THROUGH A BARE LIST, MATCHED. `:leaf | list<N>` has no
  # tuple anywhere: the list part is algebra-primitive and resolved in its own
  # clause, so it reaches the subtraction by a different path than R1 does, and
  # the spine has to cancel against the top's `{[], {open, any}}` for the
  # residual to come out empty.
  #
  # This shape is why the probe exists. It hung -- `is_none/2` dropped the
  # coinductive hypothesis for a bound variable and demanded a literally empty
  # spine list, so `Iodata \ term` came back inhabited and `is_subtype(Iodata,
  # term)` was FALSE. Every probe above was green while that was true.
  mk R10 'module R10

type N = :leaf | list<N>

public :ok F(N n)
F(:leaf)      -> :ok
F([])         -> :ok
F([h, ..t])   -> :ok
'
  shot R10 R10 F ':leaf'
}

# ---------------------------------------------------------------------------
# --self-test -- five defects and one correct form. A check that fires on
# everything passes the red half and is worthless, so the green half is not
# optional. Each defect is a wrong implementation somebody would actually
# ship, not a scrambled string:
#
#   silent       nothing was built -- every positive still refused. Today's tree.
#   unsound      the refusal was simply dropped: `type X = X | int` compiles.
#                Passes every positive probe. A gate that only timed things
#                would go green over this.
#   hung         R8's residual walk does not terminate -- the memo table is
#                missing or disabled. Produces NO output, which is why the
#                stopwatch exists.
#   name_keyed   a binder keyed on the name currently being resolved: R1 works,
#                MUTUAL recursion does not.
#   isorecursive a nominal binder: everything works except that two spellings of
#                one type are two types. What ships is not what 09 decided.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0

  REFUSED="R.bs: error: Tree is a recursive type, and those are not built yet
  the definition is well formed -- the recursion passes through a
  constructor, so it describes a real set of values."
  NONCON="R6.bs: error: the type X is defined in terms of itself, and the
  recursion does not pass through a constructor
  so there is no set of values it could describe -- and that is
  not a missing feature. Put the recursion inside a shape (a
  tuple, a list, or a record field), or drop it."
  NONCONB="R6b.bs: error: the type Y is defined in terms of itself, and the
  recursion does not pass through a constructor
  so there is no set of values it could describe -- and that is
  not a missing feature."
  RESIDUAL="R8.bs: error: the clauses of Size do not cover Tree
  not covered: :leaf"
  # R9's round trip: the nested value comes back unchanged, which it can only do
  # if the generated validator called itself.
  VALID="(:node, :leaf, (:node, :leaf, :leaf))"

  # stub <name> <R1> <R2> <R3> <R4> <R5> <R6> <R6b> <R7> <R8> <R9>
  # every .st is `ok` unless overridden afterwards.
  stub() {
    local d="$W/$1"; shift
    mkdir -p "$d"
    local i=1
    for p in R1 R2 R3 R4 R5 R6 R6b R7 R8 R9 R10; do
      eval "printf '%s' \"\${$i}\" > \"\$d/\$p.out\""
      printf 'ok' > "$d/$p.st"
      i=$((i + 1))
    done
  }

  # The correct form: positives run, both controls refuse, the residual names
  # `:leaf`. R6/R6b exit non-zero, which `judge` reads from `.out`, not `.st`.
  stub good "2" ":ok" ":ok" ":ok" ":ok" "$NONCON" "$NONCONB" ":ok" "$RESIDUAL" "$VALID" ":ok"
  printf 'rc1' > "$W/good/R6.st"; printf 'rc1' > "$W/good/R6b.st"
  printf 'rc1' > "$W/good/R8.st"

  stub silent "$REFUSED" "$REFUSED" "$REFUSED" "$REFUSED" "$REFUSED" \
              "$NONCON" "$NONCONB" "$REFUSED" "$REFUSED" "$REFUSED" "$REFUSED"
  printf 'rc1' > "$W/silent/R6.st"; printf 'rc1' > "$W/silent/R6b.st"

  # The refusal dropped entirely: X = X | int now compiles and returns 1.
  stub unsound "2" ":ok" ":ok" ":ok" ":ok" "1" "1" ":ok" "$RESIDUAL" "$VALID" ":ok"
  printf 'rc1' > "$W/unsound/R8.st"

  # R8 never returns. Its output is empty, exactly as a real hang's is.
  stub hung "2" ":ok" ":ok" ":ok" ":ok" "$NONCON" "$NONCONB" ":ok" "" "$VALID" ":ok"
  printf 'rc1' > "$W/hung/R6.st"; printf 'rc1' > "$W/hung/R6b.st"
  printf 'hung' > "$W/hung/R8.st"

  stub name_keyed "2" ":ok" ":ok" "$REFUSED" ":ok" "$NONCON" "$NONCONB" ":ok" "$RESIDUAL" "$VALID" ":ok"
  printf 'rc1' > "$W/name_keyed/R6.st"; printf 'rc1' > "$W/name_keyed/R6b.st"
  printf 'rc1' > "$W/name_keyed/R4.st"; printf 'rc1' > "$W/name_keyed/R8.st"

  ISO="R7.bs: error: Widen returns L1 where L2 is declared"
  stub isorecursive "2" ":ok" ":ok" ":ok" ":ok" "$NONCON" "$NONCONB" "$ISO" "$RESIDUAL" "$VALID" ":ok"
  printf 'rc1' > "$W/isorecursive/R6.st"; printf 'rc1' > "$W/isorecursive/R6b.st"
  printf 'rc1' > "$W/isorecursive/R7.st"; printf 'rc1' > "$W/isorecursive/R8.st"

  # THE DEFECT THIS GATE ACTUALLY SHIPPED WITH, kept as a control because it got
  # past nine green probes. `is_none/2` dropped the coinductive hypothesis for a
  # bound variable and demanded a literally empty spine list, so the LIST part's
  # subtraction never cancelled: `Iodata \ term` came back inhabited and
  # `is_subtype(Iodata, term)` was false. The visible face is a false
  # inexhaustive on a total function over a list-recursive type. Tuple recursion
  # (R1) is unaffected, which is exactly why one probe per constructor kind is
  # not a luxury.
  LISTBLIND="R10.bs:5: error: the clauses of F do not cover N
  not covered: list<...>"
  stub list_blind "2" ":ok" ":ok" ":ok" ":ok" "$NONCON" "$NONCONB" ":ok" "$RESIDUAL" "$VALID" "$LISTBLIND"
  printf 'rc1' > "$W/list_blind/R6.st"; printf 'rc1' > "$W/list_blind/R6b.st"
  printf 'rc1' > "$W/list_blind/R8.st"; printf 'rc1' > "$W/list_blind/R10.st"

  for bad in silent unsound hung name_keyed isorecursive list_blind; do
    if [ -z "$(judge "$W/$bad")" ]; then
      echo "  x SELF-TEST: '$bad' produced no complaint - the gate cannot see it"; fail=1
    else
      echo "  ok red on $bad"
    fi
  done
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: the CORRECT form was rejected -"; judge "$W/good"; fail=1
  else
    echo "  ok green on the correct form"
  fi
  [ "$fail" -eq 0 ] || { echo "self-test FAILED"; exit 1; }
  echo "self-test passed: six defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         recursive types resolve under a ${BUDGET}s budget; the non-contractive pair still refused, ground and parametric"
