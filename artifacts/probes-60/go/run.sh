cd "$(dirname "$0")/shop"; export GOFLAGS=-mod=mod GOPROXY=off GOCACHE=/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/gocache
for p in ./orders ./orders/tests ./billing; do echo "## go build $p"; /usr/local/go/bin/go build $p 2>&1; echo "rc=$?"; done
