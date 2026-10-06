#!/usr/bin/env bash
# p4 — what do Elixir/Mix (installed 1.20.4) record about dependencies, where, and what do they check at compile time?
# Elixir's own .ex sources are NOT installed here (only .beam), so no file:line is cited for Mix; behaviour is shown by running it.
#   M1  mix.exs `deps` -> the generated ebin/<app>.app carries `{applications,[...]}` (provenance is written into the artefact)
#   M2  CONTROL: remove the dep from mix.exs -> the .app no longer lists it, and compile WARNS at compile time (not run time)
#       that the module is "not available" -- Elixir has a compile-time answer to the question 52 asks, in the compiler
#   M3  a dep on the code path via ERL_LIBS but NOT declared in mix.exs is still reported "undefined" by mix compile (mix prunes
#       code paths to the declared deps) -- Mix's verdict follows the MANIFEST, not the environment; and it is a WARNING, not an error
source "$(dirname "$0")/common.sh"
export MIX_HOME="$WORK/mixhome" HEX_HOME="$WORK/hexhome" MIX_ENV=dev
mkdir -p "$WORK/liba/lib" "$WORK/app/lib"
cat > "$WORK/liba/mix.exs" <<'EOT'
defmodule LibA.MixProject do
  use Mix.Project
  def project, do: [app: :liba, version: "0.1.0", deps: []]
  def application, do: []
end
EOT
echo 'defmodule LibA do def hi, do: 42 end' > "$WORK/liba/lib/liba.ex"
mk_app () { # mk_app <deps-literal>
  cat > "$WORK/app/mix.exs" <<EOT
defmodule App.MixProject do
  use Mix.Project
  def project, do: [app: :app, version: "0.1.0", deps: $1]
  def application, do: [extra_applications: [:logger]]
end
EOT
  echo 'defmodule App do def go, do: LibA.hi() end' > "$WORK/app/lib/app.ex"
}
mixc () { (cd "$WORK/app" && rm -rf _build && mix compile 2>&1 | sed "s|$WORK/||g"); }
echo "== M1 dep declared"; mk_app "[{:liba, path: \"../liba\"}]"; o=$(mixc); echo "$o" | tail -4
echo "--- generated app resource file:"; cat "$WORK/app/_build/dev/lib/app/ebin/app.app" | tr '\n' ' '; echo
expect "M1 .app records liba in applications" "liba" "$(cat "$WORK/app/_build/dev/lib/app/ebin/app.app")"
expect_not "M1 no 'undefined' warning when declared" "undefined" "$o"
echo "== M2 control: dep NOT declared and NOT on path"; mk_app "[]"; o=$(mixc); echo "$o" | head -8
expect "M2 compile-time warning about the missing module" "is undefined" "$o"
expect_not "M2 .app does not list liba" "liba" "$(cat "$WORK/app/_build/dev/lib/app/ebin/app.app")"
echo "== M3 present on the code path via ERL_LIBS but undeclared in mix.exs"
mkdir -p "$WORK/libs/liba/ebin"; (cd "$WORK/liba" && mix compile >/dev/null 2>&1 && cp -r _build/dev/lib/liba/ebin/* "$WORK/libs/liba/ebin/")
o=$(cd "$WORK/app" && rm -rf _build && ERL_LIBS="$WORK/libs" mix compile 2>&1 | sed "s|$WORK/||g"); echo "$o" | head -3
expect "M3 ERL_LIBS alone does NOT satisfy Mix: still 'is undefined' (Mix prunes undeclared code paths)" "is undefined" "$o"
echo "--- control: outside mix, the same ERL_LIBS does expose liba"
EV="io:format(\"~p\",[code:ensure_loaded('Elixir.LibA')]),halt()."
r=$(ERL_LIBS="$WORK/libs" erl -noshell -eval "$EV" 2>&1); echo "plain erl: ensure_loaded(Elixir.LibA) -> $r"
expect "M3 control: plain erl sees it" "{module," "$r"
finish
