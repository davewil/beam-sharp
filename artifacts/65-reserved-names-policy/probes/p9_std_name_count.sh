#!/usr/bin/env bash
# P9: how many names does a reserved-name list contain TODAY (HEAD bsc build)? Read from the compiler's own exports.
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH
escript "$(dirname "$0")/p9_std_name_count.escript"
