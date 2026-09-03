#!/usr/bin/env bash
#
# Every example module compiles — in one VM.
#
# WHY THIS EXISTS AS A GATE (ENG-314, 2026-09-03). "Examples compile and run"
# was a `find | while` loop written twice, once in `ci.yml` and once in
# `bin/verify.sh`, booting one `bsc` per module directory. Moving it onto
# `bsc --batch` meant writing a manifest, and a manifest-writing loop copied
# into two files is the drift `check-gates-wired.sh` exists to stop. So the
# loop is a script, named in both, with the `--self-test` every gate carries —
# which the inline loop never had: nothing had ever shown it going red.
#
# PER DIRECTORY SINCE F15, because a directory IS the module now (ticket 13
# §3). A per-file invocation is not merely outdated here, it is wrong: it
# emits a `.beam` missing every other file in the module, which loads, exports
# less than the module declares, and fails at the call site.
#
# A directory holding `.bs` files is a module and one holding only directories
# is a namespace (41 §5), so the walk asks for the first and passes through the
# second. `--src-root` is the corpus root because it holds dotted modules —
# `Shop.Reports` lives at `Shop/Reports` — and 41 §3 makes naming the root the
# caller's job, never the compiler's.
#
# `exemplars/` IS PRUNED, and that exclusion is the point rather than an
# oversight: ticket 25's three exemplars are the compiler's target and none of
# them parses yet. Recursing without the prune turns the must-run surface into
# a must-fail one.
#
# A CORPUS WITH NO MODULES IS RED. A loop over nothing exits 0, and this
# repository has shipped that shape before (a `19/19` over a block nothing
# enumerated). Zero modules means the root moved, not that everything compiled.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"
# `CHECK_EXAMPLES_ROOT` exists for the self-test below, which points this gate
# at copies of the corpus with one module broken. Nothing else sets it.
CORPUS="${CHECK_EXAMPLES_ROOT:-$HERE/examples}"

[ -x "$BSC" ] || {
    echo "no escript at $BSC — run \`rebar3 escriptize\` in compiler/ first" >&2
    exit 2
}

# judge ROOT — compile every module directory under ROOT, one VM for all of them.
# Prints one line per module and returns 1 if any failed or none was found.
judge() {
    local root="$1" work n=0 d status fail=0
    work="$(mktemp -d)"
    # shellcheck disable=SC2064  # $work is meant to expand now
    trap "rm -rf '$work'" RETURN

    [ -d "$root" ] || { echo "  NO MODULES  $root is not a directory"; return 1; }
    find "$root" -path "$root/exemplars" -prune -o -name '*.bs' -print0 |
        while IFS= read -r -d '' f; do dirname "$f"; done | sort -u > "$work/dirs"

    while IFS= read -r d; do
        [ -n "$d" ] || continue
        n=$((n + 1))
        mkdir -p "$work/out$n"
        printf '%s' "$d" > "$work/e$n.dir"
        # `check-language.sh`'s `manifest_entry`, written here rather than
        # sourced: `check-shell.sh` lints only executables and
        # `check-gates-wired.sh` takes every executable for a gate, so a
        # shared helper file would sit outside the one and inside the other.
        {
            printf 'entry e%d\n' "$n"
            printf 'arg %s\n' --src-root "$root" -o "$work/out$n" "$d"
            printf 'end\n\n'
        } >> "$work/manifest"
    done < "$work/dirs"

    if [ "$n" -eq 0 ]; then
        echo "  NO MODULES  nothing under $root holds a .bs file — the corpus moved"
        return 1
    fi

    if ! "$BSC" --batch "$work/manifest" "$work/results" > "$work/batch.log" 2>&1; then
        echo "  BATCH FAILED  bsc --batch could not compile the corpus; no module was judged"
        sed 's/^/                /' "$work/batch.log"
        return 1
    fi

    local i=1
    while [ "$i" -le "$n" ]; do
        d="$(cat "$work/e$i.dir")"
        status="$(cat "$work/results/e$i.status" 2>/dev/null || echo none)"
        if [ "$status" = "0" ]; then
            printf '  %-9s %s\n' "ok" "${d#"$root/"}"
        else
            printf '  %-9s %s (exit %s)\n' "FAILED" "${d#"$root/"}" "$status"
            sed 's/^/            /' "$work/results/e$i.output" 2>/dev/null || true
            fail=1
        fi
        i=$((i + 1))
    done
    echo
    if [ "$fail" -eq 0 ]; then
        echo "$n example modules compile"
    else
        echo "an example module does not compile"
    fi
    return "$fail"
}

# ---------------------------------------------------------------------------
# --self-test
#
# Three controls. A module that does not compile must be named; a root with
# nothing in it must be red rather than a quiet `0 modules compile`; and the
# corpus as committed must pass, or this gate fails every clean tree.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT
    st_fail=0

    # CONTROL 1 — one module made inexhaustive. `Fib` gains a function whose
    # only clause covers `0`, which the checker refuses by name.
    cp -R "$CORPUS" "$CTL/broken"
    printf '\npublic int Nope(int n)\nNope(0) -> 0\n' >> "$CTL/broken/Fib/fib.bs"
    out="$(judge "$CTL/broken" 2>&1)" && rc=0 || rc=$?
    case "$out" in
        *"FAILED    Fib"*) ;;
        *) echo "SELF-TEST FAILED: a module that does not compile was not named"
           echo "$out"
           st_fail=1 ;;
    esac
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: a corpus with a broken module exited 0"
        st_fail=1
    fi

    # CONTROL 2 — a root holding nothing.
    mkdir -p "$CTL/empty"
    out="$(judge "$CTL/empty" 2>&1)" && rc=0 || rc=$?
    case "$out" in
        *"NO MODULES"*) ;;
        *) echo "SELF-TEST FAILED: an empty corpus was not reported"
           st_fail=1 ;;
    esac
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: an empty corpus exited 0 — a loop over nothing passed"
        st_fail=1
    fi

    # NEGATIVE CONTROL — the corpus as committed.
    if ! judge "$CORPUS" > "$CTL/clean.out" 2>&1; then
        echo "SELF-TEST FAILED: the committed corpus was rejected, so this gate would"
        echo "                  fail every clean tree and be removed"
        cat "$CTL/clean.out"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: named the module that does not compile, refused an empty"
        echo "           corpus, and accepted the committed one — the gate discriminates"
        exit 0
    fi
    exit 1
fi

[ "${1:-}" = "" ] || { echo "usage: check-examples.sh [--self-test]"; exit 2; }

judge "$CORPUS"
