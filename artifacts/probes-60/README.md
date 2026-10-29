Probe map (ticket 60). Claim -> probe:
- Gleam internal_modules/@internal not enforced across path-dependency; private fn is: gleam/out-build.txt, gleam/out-control.txt (re-run: gleam/run.sh <gleam>)
- Elixir @moduledoc false = docs only; defp-missing is a warning; xref sees callers: elixir/out-run.txt, out-compile.txt (elixir/run.sh)
- Erlang: friend call compiles+runs, non-export -> undef, xref caller-side pass finds it: erlang/out.txt (erlang/run.sh); export_all/opaque: erlang/attrs/out.txt
- xref cost over OTP stdlib beams: erlang/out-stdlib.txt (escript erlang/xref_time.escript <ebin>)
- Go internal/ = enforced subtree rule; tests dir inside subtree allowed: go/out.txt (go/run.sh)
- Subtree-check cost model N=10/100/1000: cost/out.txt (escript cost/model.escript)
