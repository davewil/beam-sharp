#!/usr/bin/env bash
# Probe (c): bytes and call time with / without each guard on PRIVATE functions.
# Compiles src/Scope and src/Scope8 with three compiler variants, then measures in one VM.
# Needs ./build-variants.sh first.   Run: ./probe_c_cost.sh
cd "$(dirname "$0")"
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
W=${W:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59/variants}
for v in base notag widen; do
  for m in Scope Scope8 ScopeI; do BSC_EBIN=$W/$v/ebin ./bsc.sh --src-root src -o out_$v src/$m || exit 1; done
done
erl -noshell -eval 'erlang:halt(0)' >/dev/null
erlc -o /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59 probe_c_cost.erl || exit 1
erl -noshell -pa /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59 -eval 'probe_c_cost:main("'"$PWD"'"), halt().'
