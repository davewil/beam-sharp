#!/usr/bin/env bash
# Re-run every probe for ticket 52. Usage: bash artifacts/probes/52/run.sh   (writes *.out next to this file)
# Needs: nix profile on PATH (erl, elixir, mix, gleam, elm), compiler/_build/default/bin/bsc prebuilt.
set -u
export PATH=$HOME/.nix-profile/bin:$PATH LANG=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"
HERE=$(cd "$(dirname "$0")" && pwd); cd "$HERE"
BSC=$HERE/../../../compiler/_build/default/bin/bsc
EL=$(elixir -e 'IO.puts Path.dirname(:code.lib_dir(:elixir))' 2>/dev/null)

{ echo "### P1 Elixir stdlib module, ERL_LIBS unset: compile, then run"
  (cd A_missing && rm -f Up.beam Up.abstr && $BSC Up; echo "compile rc=$?"; $BSC Up Shout '"hi"'; echo "run rc=$?")
  echo "### P1 same program, ERL_LIBS=Elixir lib dir"
  (cd A_missing && ERL_LIBS=$EL $BSC Up Shout '"hi"'; echo "run rc=$?")
  echo "### P2 module that exists nowhere (Elixir.NoSuchLibrary)"
  (cd B_nomod && $BSC Nope; echo "compile rc=$?"; $BSC Nope Go '"x"'; echo "run rc=$?")
  echo "### P3 Erlang module that exists nowhere"
  (cd C_erl && $BSC Ghost; echo "compile rc=$?"; $BSC Ghost Go 1; echo "run rc=$?")
  echo "### P4 synthetic 'req' app (stand-in for Req; hex unreachable here) in two layouts"
  (cd D_req && echo "-- no ERL_LIBS"; $BSC Fetch Make
   echo "-- ERL_LIBS=otp_style (req-0.7.3/ebin)"; ERL_LIBS=$HERE/fixture/otp_style $BSC Fetch Make
   echo "-- ERL_LIBS=mix_style (req/ebin)";       ERL_LIBS=$HERE/fixture/mix_style $BSC Fetch Make)
  echo "### P5 what the .beam already records"
  erl -noshell -eval '{ok,{_,[{imports,I}]}}=beam_lib:chunks("A_missing/Up.beam",[imports]), io:format("ImpT: ~p~n",[I]), {ok,_,Cs}=beam_lib:all_chunks("A_missing/Up.beam"), io:format("chunks: ~p~n",[[N||{N,_}<-Cs]]), halt().'
} > bsc_missing.out 2>&1

{ for c in "B_nomod" "A_missing" "A_missing $EL"; do echo "== xref over $c"; escript xref_bsc_beam.escript $c 2>&1 | tail -4; done; } > xref_bsc_beam.out 2>&1
./census.sh > census.out 2>&1
./census_tests.sh > census_tests.out 2>&1
escript measure.escript A_missing/Up.abstr "$HERE/fixture" > measure.out 2>&1

( cd erlang_proj && erlc +debug_info -o ebin src/myapp.erl && escript probe.escript; escript probe2.escript ) > erlang.out 2>&1

( cd elixir_proj && rm -rf _build && mix compile 2>&1; echo "-- mix.exs compile.app derivation of :applications from deps: compile.app.ex:449 (read, not run)" ) > elixir.out 2>&1
( cd gleam_proj && rm -rf build manifest.toml
  echo "== @external to a module that exists nowhere, no deps"
  printf 'name = "p"\nversion = "1.0.0"\n\n[dependencies]\n' > gleam.toml
  printf '@external(erlang, "Elixir.NoSuchLibrary", "frob")\npub fn frob(x: Int) -> Int\n\npub fn main() -> Int {\n  frob(1)\n}\n' > src/p.gleam
  gleam build 2>&1; grep applications build/dev/erlang/p/ebin/p.app
  echo "== import of a gleam module, dependency declared in gleam.toml (path dep)"
  printf 'name = "p"\nversion = "1.0.0"\n\n[dependencies]\ndep = { path = "../gleam_dep" }\n' > gleam.toml
  printf 'import dep\n\npub fn main() -> Int {\n  dep.one()\n}\n' > src/p.gleam
  rm -rf build manifest.toml; gleam build 2>&1; grep applications build/dev/erlang/p/ebin/p.app
  echo "== same import, dependency NOT declared"
  printf 'name = "p"\nversion = "1.0.0"\n\n[dependencies]\n' > gleam.toml
  rm -rf build manifest.toml; gleam build 2>&1 | head -12 ) > gleam.out 2>&1
( cd elm_proj && timeout 90 elm make src/Main.elm --output=/dev/null 2>&1 | head -12 ) > elm.out 2>&1
rm -f gleam1.out gleam2.out gleam3.out gleam4.out gleam5.out elm1.out erlang2.out
echo done
