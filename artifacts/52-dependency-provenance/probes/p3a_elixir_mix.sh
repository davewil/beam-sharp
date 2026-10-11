#!/usr/bin/env bash
# Probe (c), Elixir: what does mix/elixirc say about an undefined remote module, and
# what does mix.exs record? Run: ./p3a_elixir_mix.sh
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
export ELIXIR_ERL_OPTIONS="+fnu"
export LC_ALL=C.UTF-8; export W="$FX/mixcase"; rm -rf "$W"; mkdir -p "$W"
mk() { # name  deps-line  module-body
  local d="$W/$1"; mkdir -p "$d/lib"
  cat > "$d/mix.exs" <<MIX
defmodule C.MixProject do
  use Mix.Project
  def project, do: [app: :c, version: "0.1.0", deps: deps()]
  def application, do: [extra_applications: [:logger]]
  defp deps, do: [$2]
end
MIX
  printf '%s\n' "$3" > "$d/lib/c.ex"
  ( cd "$d" && echo "--- [$1] deps=[$2]" && ELIXIR_ERL_OPTIONS="+fnu" $4 mix compile 2>&1 | grep -v "^Compiling\|^Generated\|native name" )
}
echo "== 1. module that exists nowhere"
mk nowhere "" 'defmodule C do
  def f, do: Nonexistent.Mod.go(1)
end' env
echo
echo "== 2. dep app exists on disk but is NOT listed in deps (reach it via ERL_LIBS)"
mk unlisted "" 'defmodule C do
  def f, do: ExDep.shout("x")
end' "env ERL_LIBS=$FX/libA"
echo
echo "== 3. dep listed as a path dependency (control: no warning expected)"
mk listed "{:exdep, path: \"$FX/src/exdep\"}" 'defmodule C do
  def f, do: ExDep.shout("x")
end' env
echo
echo "== 4. dep listed, function that does not exist in it"
mk listed_badfun "{:exdep, path: \"$FX/src/exdep\"}" 'defmodule C do
  def f, do: ExDep.nope("x")
end' env
echo
echo "== 5. NEGATIVE CONTROL: Elixir stdlib module (app :elixir, never listed) must be silent"
mk stdlib "" 'defmodule C do
  def f, do: String.upcase("x")
end' env
echo
echo "== 6. mix.exs for case 3 (the declaration lives in the project file, not in the source)"
cat "$W/listed/mix.exs"
echo "== 7. what mix wrote to the compiled .app of case 3 (applications key records the dep for runtime)"
cat "$W/listed/_build/dev/lib/c/ebin/c.app" 2>/dev/null
echo
echo "== 8. is anything about deps recorded INSIDE the compiled c.beam? (chunks/attributes)"
erl -noshell -eval '
 {ok,{_,[{attributes,A}]}} = beam_lib:chunks(hd(filelib:wildcard(os:getenv("W")++"/listed/_build/dev/lib/c/ebin/*.beam")),[attributes]),
 io:format("~p~n",[A]), halt().' 
