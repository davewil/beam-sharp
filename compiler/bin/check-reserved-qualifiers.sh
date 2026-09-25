#!/usr/bin/env bash
#
# `List` IS AN OPERATION SET THE COMPILER KNOWS, NOT A MODULE IT SHIPS.
#
# Ticket 67 chose (b) over (a), and the two are indistinguishable from anything a
# program PRINTS. `List.Sum([2,2,2])` is `6` whether the operation lowered at the
# site or resolved through the module table to a shipped `List.beam`. That is the
# whole reason this gate exists and the whole reason P2 reads the compiled
# artefact's import chunk instead of its output: the eunit suite asserts the
# values, and a value cannot tell the two designs apart.
#
# TICKET 96 Q1 MOVED WHERE THE OPERATION LOWERS, NOT WHAT IS REFUSED. A standard
# operation is a row over the OTP function that already does it: `List.Sum` is
# `lists:sum/1`. So P2 now wants `lists` in the import chunk and still refuses
# any capitalised module there — `List`, `Map`, or a qualifier added later, each
# a module B# would have to ship, and none does. F32 read 67 as forbidding the stdlib call;
# 67 never weighed one, and that reading is what 96 Q1 overturned.
#
# THE OVER-INFORMED STUB IS THE POINT OF THE SELF-TEST. `shipped_module` below
# gets P1 right — it prints `6` — and is 67's (a). A gate that only checked the
# value would pass it, ship the wrong design, and report success. It is the one
# stub that has to be constructed rather than merely broken.
#
# THREE RULES THAT FAIL IN OPPOSITE DIRECTIONS, hence three pairs of probes.
# Every refusal here has a neighbouring program that must still be ACCEPTED, and
# a check missing that half passes the red probe while being wrong:
#
#   P3 `module List` is refused        · P4 `module Shop.List` is NOT — 67 Q6
#                                          declined burning the path segment, so
#                                          a check on the dotted path takes the
#                                          option the ticket refused
#   P5 `using Shop` + `List.Sum(…)`    · P6 `using Shop` + `Ints.Sum(…)` is NOT —
#      is refused                          the namespace tier still works; it is
#                                          one word that cannot be its short name
#   P7 an operation the table lacks    · and it must NOT be reported as a missing
#      is refused                          import: "add `using List`" is advice
#                                          that can never work
#
# P7's second half is a real regression risk rather than a hypothetical. Measured
# on 2026-09-04, before this feature: `List.Frobnicate([n])` was refused with
# "List is called but never imported", hinting "add `using List`". Falling back to
# that path for an unknown operation would look like a working refusal and send
# every author somewhere that cannot compile.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place, so that --self-test
# drives THIS code path against fixtures rather than a second copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" p1 p2 p3 p4 p5 p6 p7
  p1="$(cat "$dir/P1.out")"; p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.out")"; p4="$(cat "$dir/P4.out")"
  p5="$(cat "$dir/P5.out")"; p6="$(cat "$dir/P6.out")"
  p7="$(cat "$dir/P7.out")"

  [ "$p1" = "6" ] || \
    echo "P1: List.Sum([2,2,2]) gave '$p1', wanted 6 — the reserved qualifier does not resolve"

  ## THE EMISSION, AND THE ONLY PROBE THAT SEPARATES 67's (a) FROM ITS (b).
  ## `p2` is every module the compiled beam calls remotely. A lowered operation
  ## contributes OTP's own module (`lists`, 96 Q1); a resolved one contributes
  ## exactly the module it resolved to, and every reserved qualifier is a module
  ## B# would have to ship.
  case " $p2 " in
    ## Red rather than silent: see the probe. An unreadable beam and a beam
    ## calling nothing both produce an empty import list.
    *" BEAM-UNREADABLE "*)
      echo "P2: called_modules could not read the beam, so this probe read nothing — and reading nothing is what a correct answer looks like here" ;;
    ## The probe imports nothing, and every OTP module is lowercase, so any
    ## capitalised module here is one B# would have to ship — `List` and `Map`
    ## today, and every qualifier the standard environment adds (96) without
    ## this arm being edited.
    *" "[[:upper:]]*)
      echo "P2: the beam calls out to a capitalised module ('$p2') — a reserved qualifier names no module B# ships" ;;
    *" lists "*) ;;
    *) echo "P2: the beam does not call 'lists' ('$p2') — 96 Q1 lowers List.Sum to lists:sum/1, not to a generated local form" ;;
  esac

  case "$p3" in
    *reserved*) ;;
    *) echo "P3: 'module List' was not refused as a reserved name (got '$p3')" ;;
  esac
  ## The control for P3. 67 Q6 declined option (i) — burning the SEGMENT — so
  ## only the bare name is taken. A rule written against the whole dotted path
  ## satisfies P3 and is the decision the ticket did not take.
  case "$p4" in
    *error*) echo "P4: 'module Shop.List' was refused — 67 Q6 declined burning the path segment (got '$p4')" ;;
    *) ;;
  esac

  case "$p5" in
    *reserved*) ;;
    *) echo "P5: a namespace import shadowing the reserved 'List' was not refused at the call (got '$p5')" ;;
  esac
  ## 47's rule is a DIAGNOSTIC, not a refusal: the message hands over the fix.
  ## A message naming only the reserved word tells an author nothing to do.
  case "$p5" in
    *Shop.List*) ;;
    *) echo "P5: the collision did not print the full path as the fix (got '$p5')" ;;
  esac
  ## The cry-wolf control. A check that fires on every short qualifier satisfies
  ## P5 and has removed the namespace tier from the language.
  [ "$p6" = "6" ] || \
    echo "P6: a NON-reserved short qualifier gave '$p6', wanted 6 — the check fired on the namespace tier at large"

  case "$p7" in
    *Frobnicate*) ;;
    *) echo "P7: an operation the reserved qualifier lacks was not refused by name (got '$p7')" ;;
  esac
  case "$p7" in
    *"never imported"*|*"using List"*)
      echo "P7: the unknown operation fell through to the import advice — 'using List' can never work" ;;
    *) ;;
  esac
}

# ---------------------------------------------------------------------------
# probe — one directory per module, which F15 requires: a module's declaration
# and its path are the same name written twice, so a shared `src/` is refused
# before any of this gate's opinions are reached.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1"
  mkdir -p "$dir/src/P" "$dir/src/Shop/List" "$dir/src/Shop/Ints" \
           "$dir/src/R" "$dir/src/Q" "$dir/bad/List" "$dir/out"

  printf 'module P\n\npublic int Go(int n)\nGo(n) -> List.Sum([n, n, n])\n' \
    > "$dir/src/P/P.bs"
  printf 'module Shop.List\n\npublic int Sum(list<int> xs, int acc)\nSum([], acc) -> acc\nSum([x, ..rest], acc) -> Sum(rest, acc + x)\n' \
    > "$dir/src/Shop/List/List.bs"
  printf 'module Shop.Ints\n\npublic int Sum(list<int> xs, int acc)\nSum([], acc) -> acc\nSum([x, ..rest], acc) -> Sum(rest, acc + x)\n' \
    > "$dir/src/Shop/Ints/Ints.bs"
  printf 'module R\n\nusing Shop\n\npublic int Go(int n)\nGo(n) -> List.Sum([n, n, n], 0)\n' \
    > "$dir/src/R/R.bs"
  printf 'module Q\n\nusing Shop\n\npublic int Go(int n)\nGo(n) -> Ints.Sum([n, n, n], 0)\n' \
    > "$dir/src/Q/Q.bs"
  printf 'module List\n\npublic int Go(int n)\nGo(n) -> n\n' \
    > "$dir/bad/List/List.bs"

  "$BSC" --src-root "$dir/src" "$dir/src/P" Go 2 > "$dir/P1.out" 2>&1 || true

  ## P2 compiles rather than runs, because the subject is the ARTEFACT. `-o` is
  ## what makes the beam readable; the run above never writes one out.
  "$BSC" --src-root "$dir/src" -o "$dir/out" "$dir/src/P" >/dev/null 2>&1 || true
  ## `|| true` HERE WOULD MAKE P2 VACUOUS, and P2 is the only probe that
  ## separates 67's (a) from its (b). `called_modules` reads the beam's import
  ## chunk; if it cannot — no beam, a chunk it does not understand, a `beam_lib`
  ## error — it writes nothing, and an EMPTY IMPORT LIST IS EXACTLY WHAT A
  ## CORRECTLY INLINED OPERATION PRODUCES. The judge below would fall through its
  ## `case` to the passing arm and the gate would go green having read nothing.
  ## That is be6307b's shape, and a 2026-09-04 sweep for swallowed statuses is
  ## what found it here.
  if ! called_modules "$dir/out/P.beam" > "$dir/P2.out" 2>&1; then
    printf 'BEAM-UNREADABLE\n' > "$dir/P2.out"
  fi

  "$BSC" --src-root "$dir/bad" "$dir/bad/List" Go 1 > "$dir/P3.out" 2>&1 || true
  "$BSC" --src-root "$dir/src" "$dir/src/Shop/List" Sum '[1]' 0 > "$dir/P4.out" 2>&1 || true
  "$BSC" --src-root "$dir/src" "$dir/src/R" Go 2 > "$dir/P5.out" 2>&1 || true
  "$BSC" --src-root "$dir/src" "$dir/src/Q" Go 2 > "$dir/P6.out" 2>&1 || true

  printf 'module P\n\npublic int Go(int n)\nGo(n) -> List.Frobnicate([n])\n' \
    > "$dir/src/P/P.bs"
  "$BSC" --src-root "$dir/src" "$dir/src/P" Go 2 > "$dir/P7.out" 2>&1 || true
}

# Every module the beam calls remotely, from its own import chunk.
#
# RUN FROM A DIRECTORY THAT IS NOT `compiler/`. A bare `erl` started inside
# `compiler/` picks up the `C.beam` in the build tree ahead of stdlib's own `c`
# module and dies before evaluating anything — this repo's standing trap, and the
# reason `cd` here is deliberate rather than incidental.
called_modules() {
  local beam="$1"
  ( cd / && erl -noshell -eval '
      [B] = init:get_plain_arguments(),
      case beam_lib:chunks(B, [imports]) of
        {ok, {_, [{imports, Is}]}} ->
          io:format("~s~n", [lists:join(" ", [atom_to_list(M)
                                              || M <- lists:usort([X || {X,_,_} <- Is])])]);
        _ -> io:format("NO-BEAM~n")
      end,
      halt(0).' -- "$beam" 2>/dev/null ) || echo "NO-BEAM"
}

# ---------------------------------------------------------------------------
# --self-test — nine defects and one correct form.
#
# A check that fires on everything passes the red half and is worthless, so the
# green half is not optional. Three of the nine are CRY-WOLF stubs: they satisfy
# a red probe by being too aggressive, which is the failure mode a gate written
# only from the refusals cannot see.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  RESERVED="error: \`List\` is a reserved qualifier"
  COLLIDE="error: \`List\` is a reserved qualifier and \`using Shop\` also short-qualifies \`Shop.List\` to it; write \`Shop.List.Sum\` in full"
  NOOP="error: \`List\` has no operation \`Frobnicate/1\`"
  stub() {
    mkdir -p "$W/$1"
    printf '%s' "$2" > "$W/$1/P1.out"; printf '%s' "$3" > "$W/$1/P2.out"
    printf '%s' "$4" > "$W/$1/P3.out"; printf '%s' "$5" > "$W/$1/P4.out"
    printf '%s' "$6" > "$W/$1/P5.out"; printf '%s' "$7" > "$W/$1/P6.out"
    printf '%s' "$8" > "$W/$1/P7.out"
  }
  #                 P1    P2                 P3          P4  P5         P6   P7
  stub good         "6"   "erlang lists"     "$RESERVED" "1" "$COLLIDE" "6"  "$NOOP"
  ## 67's (a) WEARING (b)'s OUTPUT — the over-informed stub. Right answer,
  ## wrong design, and only P2 can see it.
  stub shipped_module "6" "List erlang lists" "$RESERVED" "1" "$COLLIDE" "6"  "$NOOP"
  ## The same shape under the qualifier that has no operations yet.
  stub shipped_map    "6" "Map erlang lists"  "$RESERVED" "1" "$COLLIDE" "6"  "$NOOP"
  ## A qualifier ticket 96 adds later, which a list of today's names would miss.
  stub shipped_enum   "6" "Enum erlang lists" "$RESERVED" "1" "$COLLIDE" "6"  "$NOOP"
  ## F32's lowering, which 96 Q1 replaced: the right value from a generated
  ## local walker, and no call into OTP.
  stub generated_local "6" "erlang"           "$RESERVED" "1" "$COLLIDE" "6"  "$NOOP"
  ## Clause 2 absent — measured to be today's state, so this is the stub that
  ## proves the gate would have caught the eight days 48's reservation sat unbuilt.
  stub no_reservation "6" "erlang lists"     "1"         "1" "$COLLIDE" "6"  "$NOOP"
  ## CRY-WOLF: burning the path segment, which is the option 67 Q6 declined.
  stub over_reserved  "6" "erlang lists"     "$RESERVED" "error: \`List\` is a reserved qualifier" \
                                                             "$COLLIDE" "6"  "$NOOP"
  ## Clause 3 absent — the namespace import silently wins, which is Elixir's
  ## clobber and the thing 67 refused.
  stub no_collision   "6" "erlang lists"     "$RESERVED" "1" "6"        "6"  "$NOOP"
  ## CRY-WOLF: the collision check fires on every short qualifier, removing the
  ## namespace tier from the language while satisfying P5.
  stub collides_wide  "6" "erlang lists"     "$RESERVED" "1" "$COLLIDE" \
                             "error: \`Ints\` is a reserved qualifier" "$NOOP"
  ## The unknown operation falls through to the import advice.
  stub stale_advice   "6" "erlang lists"     "$RESERVED" "1" "$COLLIDE" "6" \
                             "error: List is called but never imported"

  for bad in shipped_module shipped_map shipped_enum generated_local no_reservation over_reserved \
             no_collision collides_wide stale_advice; do
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
  echo "self-test passed: nine defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         List/Term/Map/Float are reserved qualifiers, lowered to OTP at the site and refused when shadowed"
