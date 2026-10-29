#!/usr/bin/env bash
# Re-runs every probe in this directory from the REAL repo grammar. Needs only OTP 25 (yecc). Never edits the repo.
set -euo pipefail
cd "$(dirname "$0")"
REPO=${REPO:-/home/user/beam-sharp}
rm -rf var erl_work && mkdir var
python3 mkvariants.py "$REPO/compiler/src/bs_parser.yrl"
escript conflicts.escript > conflicts_out.txt 2>&1; cat conflicts_out.txt
(cd var && erlc *_p.erl)
escript parse_var.escript base > parse_base_out.txt 2>&1
for v in base g1 g1c g2; do echo "##### $v"; escript parse_var.escript $v 2>&1; done > variants_ast_out.txt
escript model.escript > model_out.txt 2>&1; cat model_out.txt
escript guard.escript > guard_out.txt 2>&1; escript opaque.escript > opaque_out.txt 2>&1; escript neglit.escript > neglit_out.txt 2>&1
mkdir erl_work && cp erl/e.erl erl/s.escript erl/pat.escript erl_work/ && (cd erl_work && escript s.escript > ast_out.txt 2>&1; erlc -S e.erl; escript pat.escript >/dev/null 2>&1; erlc -S p.erl; grep -n 'is_ge\|integer' e.S p.S > beam_out.txt)
(cd ex && elixir q.exs > ../ex_out.txt 2>&1 || true; elixirc m.ex && elixir ab.exs > ../ex_abstract_out.txt 2>&1; rm -f Elixir.M.beam)
echo "gleam: see gl/neg/src/neg.gleam, build with: gleam build (needs empty [dependencies] in gleam.toml; hex unreachable) -> gleam_neg.erl"
