# shared by the 62 probes. Builds Shop + Shop.Reports with the scratch OTP25 bsc into $EB.
SCR=${SCR:-/tmp/claude-0/-home-user-beam-sharp/2fe6ea1f-3b09-568f-980f-d43cdc197de1/scratchpad}
REPO=/home/user/beam-sharp
BSC_EBIN=${BSC_EBIN:-/tmp/bsbuild/ebin}
bsc() { erl -noshell -pa "$BSC_EBIN" -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@"; }
build_shop() { EB=$1; mkdir -p "$EB"; (cd $REPO/compiler && bsc --src-root examples -o "$EB" examples/Shop && bsc --src-root examples -o "$EB" examples/Shop/Reports) 2>&1 | head -5; }
