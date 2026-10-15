#!/usr/bin/env bash
# PROBE 62_alias_eunit (ticket 62, option 2): which of the repo's own eunit tests
# does the alias patch break, against a STOCK baseline run of the same suite in the
# same environment? (Slow: two full `rebar3 eunit` runs, ~5 min each.)
# REFUTES "the alias patch is compatible with existing decisions" if the
# patched-only failure list is non-empty (it names the pinned behaviour it breaks).
# Control: the stock run's own failures (environment: locale, missing tools) are
# subtracted; a failure present in both is not charged to the patch.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"
W="$(bs_scratch)"; trap 'rm -rf "$W"' EXIT
for v in stock proto; do
  cp -r "$REPO/compiler" "$W/$v"; rm -rf "$W/$v/_build"
  if [ $v = proto ]; then mkdir -p "$W/p"; ( cd "$W/p" && mkdir -p compiler && cp -r "$W/proto/." compiler/ && cd "$W/p" && patch -p1 < "$HERE/62_alias_exports.patch" >/dev/null ) || exit 2; rm -rf "$W/proto"; mv "$W/p/compiler" "$W/proto"; fi
  ( cd "$W/$v" && timeout 900 rebar3 eunit > "$W/$v.log" 2>&1 )
  grep -E "^\s+[a-z_]+: .*\*failed\*" "$W/$v.log" | sed 's/\.\.\..*//; s/^ *//' | sort > "$W/$v.fail"
  echo "$v: $(grep -E 'Failed: |All [0-9]+ tests passed' "$W/$v.log" | tail -1)"
done
echo "--- failing ONLY under the alias patch ---"; comm -13 "$W/stock.fail" "$W/proto.fail"
echo "--- failing in both (environment, not charged to the patch) ---"; comm -12 "$W/stock.fail" "$W/proto.fail"
