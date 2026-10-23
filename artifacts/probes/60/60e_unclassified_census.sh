#!/usr/bin/env bash
# PROBE 60e — how big is ticket 24 §2's `unclassified` remainder in the repo's own programs?
# 24 §2: in a behaviour module, functions are  callbacks | client API | unclassified (helpers).
# F12 (public/private, private by default) shipped after 24 was written; so the live question is:
# among PUBLIC functions of behaviour modules, how many are neither a GenServer callback nor the
# declared client API, and how many modules even have the shape? Counts SIGNATURE lines (a line that
# starts a function declaration), by source text, because the exemplars do not compile yet (so --api
# cannot be asked). The method is stated, not hidden: a regex over `.bs` text.
# KNOWN LIMIT (the control at the bottom shows it): the regex misses signatures whose type contains `->`
# (fn-typed) or that open a `{` body -- 6 of 100 public signatures in the compiled corpus (Pricing, Discounts,
# Signalbox), none in a behaviour module; Counter's 3 are confirmed by `bsc --api`. The exemplar count agrees.
# Run from anywhere. No toolchain needed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; EX="$HERE/../../../compiler/examples"
CB='^(Init|HandleCall|HandleCast|HandleInfo|HandleContinue|Terminate|CodeChange)$'
# a signature: optional visibility, a return-type token(s), Name(  at column 0, no `->` on the line
sigs() { grep -hE '^(public |private )?[^ /][^=]* [A-Z][A-Za-z0-9]*\(.*\)[[:space:]]*$' "$1" | grep -vE -- '->|^(using|module|record|type|behaviour|implements)' ; }
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
echo "== control: the regex's public count must equal an independent count (grep -c of lines starting 'public ')"
for scope in compiled exemplars; do
  if [[ $scope == compiled ]]; then files=$(find "$EX" -name '*.bs' -not -path '*/exemplars/*'); else files=$(find "$EX/exemplars" -name '*.bs'); fi
  ind=0; for f in $files; do ind=$((ind + $(grep -c '^public ' "$f"))); done
  mine=0; for f in $files; do mine=$((mine + $(sigs "$f" | grep -c '^public '))); done
  echo "   $scope: independent=$ind  regex=$mine  $([ "$ind" = "$mine" ] && echo AGREE || echo DISAGREE)"
done
