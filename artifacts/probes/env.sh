# Source me. Puts the probe toolchain on PATH and defines `bsc`.
# Toolchain (installed this session, nothing in the repo changed):
#   erlang OTP 29 / elixir 1.20.4 / gleam 1.19.1  <- conda-forge via micromamba
#   elm 0.19.1                                    <- npm @lydell/elm
#   bsc                                           <- compiler/src built with erlc (leex+yecc) into $S/c/ebin
S=${PROBE_ROOT:-/tmp/claude-0/-home-user-beam-sharp/9e1be94a-467c-500c-b3af-f1c9458ae78e/scratchpad}
export PATH=$S/mamba/envs/beam/bin:$S/elm/node_modules/.bin:$PATH
export ELIXIR_ERL_OPTIONS="+fnu"
export ELM_HOME=$S/elmhome
bsc() { erl -noshell -pa ${BSC_EBIN:-$S/c/ebin} -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@"; }
# Fresh scratch dir per probe, outside the repo.
work() { W=$S/work/$1; rm -rf "$W"; mkdir -p "$W"; cd "$W"; }
