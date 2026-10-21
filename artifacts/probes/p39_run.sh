#!/usr/bin/env bash
# Ticket 39: the benchmark's own table, on this machine (OTP 28, x86-64 JIT; the ticket's was Apple Silicon).
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
erl -noshell -pa $PROBE_HOME/b39/ebin -eval 'bench:main(["'$root'/aoc/2025/Day01/input.txt"])'
