#!/usr/bin/env bash
# p07: what does Elixir (1.14) do about a call into a module the code path does or does not provide?
# Needs /tmp/mixdeps52b (mix path dep `libdep`), built by the commands in brief.md "Reproduce".
cd "$(dirname "$0")/neighbours/exlib"
O=$(mktemp -d)
LD=/tmp/mixdeps52b/consumer/_build/dev/lib/libdep/ebin
echo '--- A. elixirc, libdep NOT on path'
env -u ERL_LIBS elixirc -o $O use_libdep.ex 2>&1; echo "exit=${PIPESTATUS[0]}"
echo '--- B. elixirc, libdep on path (-pa)'
env -u ERL_LIBS elixirc -pa $LD -o $O use_libdep.ex 2>&1; echo "exit=${PIPESTATUS[0]}"
echo '--- C. elixirc, module name typo (Libdpe), libdep on path'
env -u ERL_LIBS elixirc -pa $LD -o $O use_typo.ex 2>&1; echo "exit=${PIPESTATUS[0]}"
