#!/usr/bin/env bash
#
# A TEST HELPER MUST REPORT WHAT THE COMPILER REPORTS.
#
# This is the circular-prototype class: a harness that supplies the answer it is
# supposed to be measuring. The repo has it on record twice.
#
#   Ticket 15 lost a session to "a harness that supplied the protection it was
#   measuring" — the sentence `spec-check.sh` still carries as its reason for
#   having controls at all.
#
#   F14 found `check_only/1` calling `bs_parser:parse` directly and skipping the
#   lowering. An unlowered `e_valve` falls through `type_of/3`'s catch-all to
#   `term()`, so — in that commit's words — "every valve assertion about clean
#   source would have passed while nothing was checked at all". The tests were
#   green because the helper had quietly agreed with them.
#
# THE HOLE IS STILL STRUCTURALLY OPEN, which is why the gate is worth more than
# the fix was. `check_only/1` now performs lex → parse → `bs_lower:valves` →
# `bs_check:check`, which is what `bsc:parse_string/2` does — but it PERFORMS it
# rather than CALLING it. The two are a copy, and nothing enforces the copy. The
# next pass added to the front end re-opens the identical defect silently, and
# in the same direction: the helper sees less than the compiler, so it complains
# about less.
#
# WHY THE COMPARISON IS ON THE TAG, NOT ON PASS/FAIL.
#
# The first draft of this gate asked only whether both rejected the source, and
# its self-test caught it being useless: the pre-F14 helper REJECTS the valve
# probe too. An unlowered valve types as `term()`, which does not match the
# declared `int`, so the bypassing helper returns `return_not_declared` where
# the compiler returns `valve_on_infallible`. Both say "no". They disagree
# completely about what is wrong, and a helper that is right by coincidence is
# the thing this gate exists to find.
#
# So the comparison is between DIAGNOSTIC TAGS. F16 published exactly the
# channel this needs — `bsc --diagnostics term` writes one descriptor per line
# on stdout, each carrying `tag => ...` — and this is the first consumer of it
# outside the tests, which is some evidence the channel was worth building.
#
# THE PROBES ARE TWO AND THE PAIR IS DELIBERATE:
#
#   `valve_on_infallible` is produced only AFTER lowering. It is the exact
#   defect F14 fixed, so it is the probe with discriminating power.
#
#   `wrong_return_type` is produced by the checker on any path. If a change ever
#   makes the first probe stop discriminating, this one going quiet says the
#   harness broke rather than that the helper improved.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EBIN="$HERE/_build/test/lib/bsc/ebin"
TESTBEAMS="$HERE/_build/test/lib/bsc/test"
BSC="$HERE/_build/test/bin/bsc"
[ -x "$BSC" ] || BSC="$HERE/_build/default/bin/bsc"

# The helper under test, as an Erlang expression over a bound `Src`. A parameter
# rather than a hardcoded call, so --self-test drives the SAME comparison over a
# deliberately broken helper instead of over a second implementation of it.
REAL_HELPER='bs_test_support:check_only(Src)'

# The historical defect, reconstructed exactly: lex, parse, check — no lowering.
#
# THE VARIABLE NAMES ARE NOT ARBITRARY. This block is spliced into the -eval
# below, and Erlang scoping is flat: a `Ds` bound in here is still bound in the
# `case` that follows, so `{error, Ds}` stops being a fresh binding and becomes
# a MATCH against the parser's output. It never matches, the catch-all returns
# `[]`, and the control reports "no diagnostics" — passing the self-test for a
# reason that has nothing to do with the defect. That happened, and it is the
# same shape as the bug this whole gate is about: a harness quietly supplying
# its own answer. The names are prefixed so they cannot collide.
BYPASS_HELPER='begin
    {ok, BypassToks, _} = bs_lexer:string(Src),
    {ok, BypassDecls} = bs_parser:parse(BypassToks),
    bs_check:check(BypassDecls)
  end'

probe_src() {
  case "$1" in
    valve_on_infallible)
      printf 'module W\nprivate int Twice(int v)\nTwice(v) -> v * 2\npublic int Run(int n)\nRun(n) -> n |?> Twice()\n' ;;
    wrong_return_type)
      printf 'module T\npublic int F(int n)\nF(n) -> :oops\n' ;;
  esac
}
probe_module() { case "$1" in valve_on_infallible) echo W ;; wrong_return_type) echo T ;; esac; }

# The compiler's tags, from the published descriptor channel. Sorted and unique
# so the comparison is about WHICH diagnostics, not their order.
compiler_tags() {
  local root="$1" dir="$2"
  "$BSC" --diagnostics term --src-root "$root" -o "$(mktemp -d)" "$dir" 2>/dev/null \
    | sed -n 's/.*tag => \([a-z_][a-z_0-9]*\).*/\1/p' | sort -u
}

# The helper's tags. The source is read from a FILE rather than interpolated
# into -eval: a `.bs` program is multi-line and full of quotes, and building one
# into a shell string is the mangling failure this repo already owns once.
helper_tags() {
  local src_file="$1" expr="$2"
  erl -noshell -pa "$EBIN" -pa "$TESTBEAMS" -eval "
    {ok, Bin} = file:read_file(\"$src_file\"),
    Src = binary_to_list(Bin),
    Diags =
      case (catch ($expr)) of
        {error, Ds} when is_list(Ds) -> Ds;
        {ok, _, Ds} when is_list(Ds) -> Ds;
        _ -> []
      end,
    Tags = [begin
              P = element(4, D),
              case is_tuple(P) of true -> element(1, P); false -> P end
            end || D <- Diags, is_tuple(D), tuple_size(D) >= 4,
                   element(1, D) =:= error],
    [io:format(\"~s~n\", [atom_to_list(T)]) || T <- lists:usort(Tags)],
    halt(0)." 2>/dev/null | sort -u
}

# Compare one helper against the compiler across the corpus. One line per
# disagreement; silence means they agree everywhere.
compare() {
  local expr="$1"
  local probe root dir src_file want got
  for probe in valve_on_infallible wrong_return_type; do
    root="$(mktemp -d)"
    dir="$root/$(probe_module "$probe")"
    mkdir -p "$dir"
    src_file="$dir/in.bs"
    probe_src "$probe" > "$src_file"

    want="$(compiler_tags "$root" "$dir" | tr '\n' ' ' | sed 's/ *$//')"
    got="$(helper_tags "$src_file" "$expr" | tr '\n' ' ' | sed 's/ *$//')"

    if [ -z "$want" ]; then
      printf '%s: THE PROBE IS STALE — bsc reports nothing, so it cannot discriminate\n' "$probe"
    elif [ "$want" != "$got" ]; then
      printf '%s: bsc reports [%s] and the helper reports [%s]\n' "$probe" "$want" "${got:-none}"
    fi
  done
}

# ---------------------------------------------------------------------------
# --self-test
#
# The positive control is not a stand-in for the defect, it IS the defect: the
# pre-F14 helper, lexing and parsing and checking with the lowering left out.
# The negative control is the helper the suite actually uses.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  [ -d "$TESTBEAMS" ] || { echo "SELF-TEST CANNOT RUN: no test beams — run \`rebar3 eunit\` first"; exit 1; }
  [ -x "$BSC" ] || { echo "SELF-TEST CANNOT RUN: no escript — run \`rebar3 escriptize\` first"; exit 1; }

  bypass_out="$(compare "$BYPASS_HELPER" || true)"
  real_out="$(compare "$REAL_HELPER" || true)"

  fail=0
  if ! grep -q '^valve_on_infallible:' <<<"$bypass_out"; then
    echo "SELF-TEST FAILED: the pre-F14 helper skipped the lowering and was NOT caught."
    echo "                  This check cannot see the defect it was written for."
    fail=1
  fi
  if [ -n "$real_out" ]; then
    echo "SELF-TEST FAILED: the real helper was reported as disagreeing:"
    printf '%s\n' "$real_out"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: the bypassing helper was caught reporting the wrong defect —"
    printf '  %s\n' "$bypass_out"
    echo "           the real helper agreed on every probe. The gate discriminates."
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
if [ ! -d "$TESTBEAMS" ] || [ ! -x "$BSC" ]; then
  echo "the test beams or the escript are missing, so the helper cannot be run."
  echo "This is a failure rather than a skip: run \`rebar3 escriptize && rebar3 eunit\` first."
  exit 1
fi

disagreements="$(compare "$REAL_HELPER" || true)"

if [ -n "$disagreements" ]; then
  printf '%s\n' "$disagreements"
  echo
  echo "The helper names a different defect from the one the compiler names, which"
  echo "means it is not walking the compiler's path. Every assertion resting on it"
  echo "is measuring a compiler that does not exist. Make the helper CALL the front"
  echo "end rather than reproduce it."
  exit 1
fi

echo "the check helper reports exactly what bsc reports on every probe"
