# shared helpers; sourced by probes
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source $S/env.sh
export ELIXIR_ERL_OPTIONS="+fnu"
REPO=/home/user/beam-sharp
EX=$REPO/compiler/examples
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)}"
WORK=${WORK:-$S/62/work_$(basename "${BASH_SOURCE[1]}" .sh)}
mkdir -p "$WORK"
# bsc wrapper: the scratchpad `bsc` script cannot take flags (erl -run swallows them),
# so call bsc:main/1 directly with the same compiler ebin.
bsc() { ( cd "$WORK" && erl -noshell -pa ${BSC_EBIN:-$S/bsc-ebin} -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@" ); }
build_examples() { mkdir -p "$1"; bsc --src-root $EX -o "$1" $EX/Shop >/dev/null; bsc --src-root $EX -o "$1" $EX/Shop/Reports >/dev/null; }
