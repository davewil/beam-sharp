#!/usr/bin/env bash
# PROBE 60e — how big is ticket 24 §2's `unclassified` remainder in the repo's own programs?
# 24 §2: in a behaviour module, functions are  callbacks | client API | unclassified (helpers).
# F12 (public/private, private by default) shipped after 24 was written; so the live question is:
# among PUBLIC functions of behaviour modules, how many are neither a GenServer callback nor the
# declared client API, and how many modules even have the shape? Counts SIGNATURE lines (a line that
# starts a function declaration), by source text, because the exemplars do not compile yet (so --api
# cannot be asked). The method is stated, not hidden: a regex over `.bs` text.
# THE CONTROL CAN FAIL: the regex's public and private counts are compared with independent
# `grep -c '^public '` / `grep -c '^private '` counts, and the script EXITS NON-ZERO on any disagreement.
# WHAT THIS SCRIPT CANNOT DO: it cannot reject the hypothesis "the who-half has demand". The compiled corpus has ONE
# behaviour module (Counter) whose public functions are all callbacks, so a zero there is guaranteed by the corpus,
# not evidence about agent-written code; and the exemplars were written before any visibility feature existed.
# Run from anywhere. No toolchain needed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; EX="$HERE/../../../compiler/examples"
CB='^(Init|HandleCall|HandleCast|HandleInfo|HandleContinue|Terminate|CodeChange)$'
# a signature: optional visibility, a return type (tuple, generic, fn(..) -> .. and record names included),
# then `Name(`...`)`, optionally followed by an opening `{`; it is NOT a clause, which starts with `Name(` at column 0.
sigs() { grep -hE '^(public |private )?[^ ]+.* [A-Z][A-Za-z0-9]*(<[^(]*>)?\(.*\)[[:space:]]*(\{)?[[:space:]]*$' "$1" | grep -vE '^[A-Z][A-Za-z0-9]*\(|^(using|module|record|type|behaviour|implements) ' ; }
name() { sed -E 's/.* ([A-Z][A-Za-z0-9]*)\(.*/\1/'; }
for scope in "compiled corpus (examples/, minus exemplars)" "exemplars (do not compile today)"; do
  if [[ $scope == compiled* ]]; then files=$(find "$EX" -name '*.bs' -not -path '*/exemplars/*' | sort)
  else files=$(find "$EX/exemplars" -name '*.bs' | sort); fi
  tot=0; pub=0; priv=0; unm=0; behav=0; pubcb=0; pubother=0; list=""
  # a behaviour module = a directory with a `behaviour` line in any of its files
  bdirs=$(for f in $files; do grep -lE '^behaviour ' "$f" >/dev/null 2>&1 && dirname "$f"; done | sort -u)
  for f in $files; do
    while IFS= read -r s; do
      tot=$((tot+1)); n=$(echo "$s" | name)
      case "$s" in public\ *) pub=$((pub+1));; private\ *) priv=$((priv+1));; *) unm=$((unm+1));; esac
      if echo "$bdirs" | grep -qx "$(dirname "$f")"; then
        if [[ $s == public\ * ]]; then
          if [[ $n =~ $CB ]]; then pubcb=$((pubcb+1)); else pubother=$((pubother+1)); list="$list $(basename "$(dirname "$f")")/$n"; fi
        fi
      fi
    done < <(sigs "$f")
  done
  echo "== $scope"
  echo "   signatures: $tot   public: $pub   private(explicit): $priv   unmarked(=private by F12): $unm"
  echo "   behaviour modules (directories): $(echo "$bdirs" | grep -c .)"
  echo "   in those: public callbacks: $pubcb   public NON-callback (client API or unclassified): $pubother"
  [ -n "$list" ] && echo "   the non-callback publics:$list"
done
echo "== control: regex counts must equal independent counts (grep -c of lines starting 'public ' / 'private ')"
rc=0
for scope in compiled exemplars; do
  if [[ $scope == compiled ]]; then files=$(find "$EX" -name '*.bs' -not -path '*/exemplars/*'); else files=$(find "$EX/exemplars" -name '*.bs'); fi
  for vis in public private; do
    ind=0; mine=0
    for f in $files; do ind=$((ind + $(grep -c "^$vis " "$f"))); mine=$((mine + $(sigs "$f" | grep -c "^$vis "))); done
    if [ "$ind" = "$mine" ]; then r=AGREE; else r=DISAGREE; rc=1; fi
    echo "   $scope $vis: independent=$ind  regex=$mine  $r"
  done
done
[ "$rc" = 0 ] || { echo "CONTROL FAILED: the census above is not trustworthy"; exit 1; }
echo "CONTROL PASSED"
