# Probe environment. SCRATCH is the directory holding mm/ (micromamba env `bx`: erlang 28 / erts 16.4,
# elixir 1.20.4, gleam 1.19.1) and ebin/ (bsc built by hand, see README.md).
: "${SCRATCH:?set SCRATCH to the directory with mm/ and ebin/}"
export PATH=$SCRATCH/mm/root/envs/bx/bin:$PATH
export ELIXIR_ERL_OPTIONS="+fnu" LC_ALL=C.UTF-8
: "${BSC_EBIN:=$SCRATCH/ebin}"   # which compiler build to drive; the patched prototypes live in other ebin dirs
bsc() { erl -noshell -pa "$BSC_EBIN" -eval 'bsc:main(init:get_plain_arguments()).' -extra "$@"; }
