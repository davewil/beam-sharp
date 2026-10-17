#!/usr/bin/env bash
# Probe 9 - Go: `internal/` is enforced by the toolchain. Same shape as the B# trees.
export PATH=/usr/local/go1.25.1/bin:$PATH; here=$(cd "$(dirname "$0")" && pwd)
cd $here/go_internal && go build ./shop/billing/ && echo "billing -> internal/ledger: ok"; go build ./shop/reports/ 2>&1 | tail -1
