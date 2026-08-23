#!/usr/bin/env bash
# Ticket 22, C# half. C# is tier 1 in the borrow heuristic, and the only
# surveyed language with genuine declaration-position bodiless members.
#
#   A  the compiling cases: old-style `partial`, `abstract`, and
#      NotImplementedException in the body. What does the compiler SAY?
#   B  CONTROL: a known type error must be reported, or A means nothing.
#   C  `public partial int Apply(int)` — declaration position, visible, no
#      body. This is exactly B#'s proposed stub shape.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$HERE/csharp_unimpl"
VAR="$HERE/variants"
cd "$PROJ" || exit 1

banner() { printf '\n########## %s ##########\n' "$1"; }
build() { dotnet build --nologo -v q 2>&1 | grep -E 'error|warning|Build succeeded|Build FAILED' | head -4; }

banner "A: partial(void) unimplemented + abstract + NotImplementedException"
build
echo "---"

banner "B: CONTROL — a known type error must be reported"
cp "$VAR/ControlTypeError.cs.off" "$PROJ/ControlTypeError.cs"
build
rm -f "$PROJ/ControlTypeError.cs"
echo "---"

banner "C: public partial, declaration position, no body — B#'s stub shape"
cp "$VAR/PublicPartial.cs.off" "$PROJ/PublicPartial.cs"
build
rm -f "$PROJ/PublicPartial.cs"
