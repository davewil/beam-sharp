#!/bin/sh
# Go 1.24.7: the `internal` directory rule, enforced by the compiler driver.
export PATH=$PATH:/usr/local/go/bin
cd "$(dirname "$0")" || exit 1
go build ./shop/orders/... ; echo "[orders + orders/sub exit $?]"
go build ./shop/billing/ ./other/ 2>&1; echo "[billing + other exit $?]"
