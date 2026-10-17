# shared by all 52 probes. Override BSC to point elsewhere.
S=/tmp/claude-0/-home-user-beam-sharp/9b30e02b-d742-5d59-8509-86bd14e28edc/scratchpad
BSC=${BSC:-$S/bsc}
export PATH=/tmp/bin:$PATH
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK=${WORK:-$(mktemp -d)}
# fake application "fakereq" with one module, built by erlc, plus an .app file
mkfake() { # $1 = lib dir root
  mkdir -p "$1/fakereq-1.2.3/ebin" "$1/src"
  cat > "$1/src/fakereq.erl" <<'EOF'
-module(fakereq).
-export([new/1]).
new(Opts) -> {request, Opts}.
EOF
  erlc -o "$1/fakereq-1.2.3/ebin" "$1/src/fakereq.erl"
  cat > "$1/fakereq-1.2.3/ebin/fakereq.app" <<'EOF'
{application, fakereq, [{description,"fake"},{vsn,"1.2.3"},{modules,[fakereq]},{registered,[]},{applications,[kernel,stdlib]}]}.
EOF
}
