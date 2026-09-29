#!/usr/bin/env bash
# Probe 3: what does mix do about a missing application / dependency? (Elixir 1.14.0, hex NOT installed, no network)
# EXPECTED (stated before the run):
#  3a extra_applications: [:nope_app]  -> `mix compile` SUCCEEDS silently (mix does not check that an extra application exists at compile time)
#  3b deps: [{:req, "~> 0.4"}] not fetched -> `mix compile` REFUSES before compiling any source, with an "Unchecked dependencies" style error;
#     `mix compile --no-deps-check` gets past that check and compiles b.ex
#  3c a call to a module that exists nowhere (Nope.Module.call/1) -> `mix compile` SUCCEEDS with a warning "undefined (module Nope.Module is not available ...)"
#     (Elixir treats it as a warning, at compile time, not an error)
here=$(cd "$(dirname "$0")" && pwd)
export MIX_ENV=dev HEX_OFFLINE=1 MIX_HOME=$here/.mixhome MIX_ARCHIVES=$here/.mixhome
cd "$here"
for p in a_extra_app b_hexdep c_undef_call; do rm -rf $p/_build $p/deps; done
for p in a_extra_app c_undef_call; do
  echo "=== $p: mix compile"; (cd $p && mix compile </dev/null 2>&1; echo "exit=$?")
done
echo "=== b_hexdep: mix compile"; (cd b_hexdep && mix compile </dev/null 2>&1; echo "exit=$?")
echo "=== b_hexdep: mix compile --no-deps-check"; (cd b_hexdep && mix compile --no-deps-check </dev/null 2>&1; echo "exit=$?")
echo "=== a_extra_app: .app file's applications list"; grep -o 'applications,\[[^]]*\]' a_extra_app/_build/dev/lib/a/ebin/a.app
echo "=== a_extra_app: does starting it fail? (ensure_all_started)"
(cd a_extra_app && mix run -e 'IO.inspect(Application.ensure_all_started(:a))' </dev/null 2>&1 | tail -3)
# ---- 3d: offline-capable version of 3b, with PATH deps (hex is not installed so 3b cannot reach the deps check)
# EXPECTED (before run): a path dep whose directory does not exist -> `mix compile` REFUSES ("does not exist" / Unchecked dependencies), exit 1;
#   `--no-deps-check` lets it compile d.ex anyway (exit 0) because the check is what was refusing.
#   An uncompiled-but-present path dep -> `mix compile` builds it itself and succeeds (exit 0) and E.f() would resolve.
rm -rf d_missing_pathdep/_build d_uncompiled_pathdep/_build d_dep/_build
echo "=== 3d missing path dep: mix compile"; (cd d_missing_pathdep && mix compile </dev/null 2>&1 | head -12; echo "exit=${PIPESTATUS[0]}")
echo "=== 3d missing path dep: mix compile --no-deps-check"; (cd d_missing_pathdep && mix compile --no-deps-check </dev/null 2>&1 | head -12; echo "exit=${PIPESTATUS[0]}")
echo "=== 3d present-but-uncompiled path dep: mix compile"; (cd d_uncompiled_pathdep && mix compile </dev/null 2>&1 | head -12; echo "exit=${PIPESTATUS[0]}")
