#!/usr/bin/env bash
# Throwaway: run every gate once from a clean checkout. $1 = repo root, $2 = SPEC_CHECK_DIR.
set -u
ROOT="$1"; SPEC_DIR="$2"; fail=0

run() {
    name="$1"
    if ( cd "$2" && bash "$3" ) >"/tmp/f13_out_$name.txt" 2>&1; then
        printf '  %-28s GREEN\n' "$name"
    else
        printf '  %-28s RED\n' "$name"; tail -8 "/tmp/f13_out_$name.txt"; fail=1
    fi
}

rm -rf /tmp/bsc_eunit
if ( cd "$ROOT/compiler" && rebar3 eunit ) >/tmp/f13_out_eunit.txt 2>&1; then
    printf '  %-28s GREEN  %s\n' "eunit" "$(grep -o 'All [0-9]* tests passed' /tmp/f13_out_eunit.txt)"
else
    printf '  %-28s RED\n' "eunit"; tail -6 /tmp/f13_out_eunit.txt; fail=1
fi

run map           "$ROOT" bin/check-map.sh
run surface       "$ROOT" bin/check-surface.sh
run links         "$ROOT" bin/check-links.sh
run shell         "$ROOT" bin/check-shell.sh
run cwd           "$ROOT" bin/check-cwd-independence.sh
run gates-wired   "$ROOT" bin/check-gates-wired.sh
run tokens        "$ROOT" editor/bin/check-tokens.sh
run language      "$ROOT/compiler" bin/check-language.sh
run diagnostics   "$ROOT/compiler" bin/check-diagnostics.sh
run tour          "$ROOT/compiler" bin/check-tour.sh
run helper-agrees "$ROOT/compiler" bin/check-helper-agrees.sh
run silent-skip   "$ROOT/compiler" bin/check-no-silent-skip.sh
run exemplars     "$ROOT/compiler" bin/extract-exemplars.sh

if ( cd "$ROOT/compiler" && SPEC_CHECK_DIR="$SPEC_DIR" bash bin/spec-check.sh ) \
        >/tmp/f13_out_spec.txt 2>&1; then
    printf '  %-28s GREEN\n' "spec-check"
else
    printf '  %-28s RED\n' "spec-check"; tail -10 /tmp/f13_out_spec.txt; fail=1
fi

echo
if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; else echo "SOMETHING IS RED"; fi
exit "$fail"
