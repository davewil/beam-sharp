# Sourced by every probe. OTP 28 for bsc; build dir is a scratch tree outside the repo.
export PATH=/opt/otp28/bin:$PATH
export BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc
export FIX=/home/user/beam-sharp/artifacts/52-dependency-provenance/verify/probes/fixtures
export W=${W:-/tmp/v52}          # scratch build tree
export ELIXIR_LIB=/usr/lib/elixir/lib
mkdir -p $W
