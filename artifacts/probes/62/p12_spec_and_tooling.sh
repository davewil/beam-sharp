#!/usr/bin/env bash
# P12: what a foreign caller's tooling SEES for an alias: -spec (via Elixir's Code.Typespec / Erlang's debug_info), and IEx tab-completion.
# CLAIM: with a delegating alias that ALSO carries a copy of the -spec, Dialyzer/ElixirLS see both names typed; with no alias spec they see
#   only the Pascal one. REFUTED IF Code.Typespec.fetch_specs shows no spec for the alias under mode=thin, or shows one under thin_nospec.
. "$(dirname "$0")/lib.sh"; build_alias_compiler || exit 1
W="$SCRATCH/p12"; rm -rf "$W"; mkdir -p "$W"
for mode in thin thin_nospec; do mkdir -p "$W/o_$mode"; BS_ALIAS=$mode "$BSC_ALIAS" --src-root "$HERE/b" -o "$W/o_$mode" "$HERE/b/Casing" >/dev/null 2>&1; done
cat > "$W/p12.exs" <<'EXEOF'
Code.prepend_path(System.get_env("BS_EBIN"))
{:ok, specs} = Code.Typespec.fetch_specs(:Casing)
names = for {{n, a}, _} <- specs, n in [:HTTPGet, :http_get, :Add2, :add2], do: {n, a}
IO.puts("  specs visible for #{inspect([:HTTPGet, :http_get, :Add2, :add2])}: #{inspect(Enum.sort(names))}")
{{:HTTPGet, 1}, [spec]} = Enum.find(specs, fn {{n, _}, _} -> n == :HTTPGet end)
IO.puts("  HTTPGet spec as Elixir prints it: " <> (Code.Typespec.spec_to_quoted(:HTTPGet, spec) |> Macro.to_string()))
EXEOF
for mode in thin thin_nospec; do echo "== BS_ALIAS=$mode"; BS_EBIN="$W/o_$mode" elixir "$W/p12.exs" 2>&1 | head -12; done
