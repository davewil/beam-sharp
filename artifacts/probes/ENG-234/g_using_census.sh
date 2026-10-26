#!/usr/bin/env bash
# (g) How many foreign `using :'…'` blocks exist per module in the repo's own .bs sources, and how many name a non-OTP module?
cd "$(git rev-parse --show-toplevel)"
echo "## files with a foreign using block that is not an OTP module (names starting Elixir. or other)"
grep -rn --include='*.bs' -E "^\s*using :'?[A-Za-z_.]+'? *\{" . 2>/dev/null | grep -v -E "using :(erlang|lists|maps|ets|string|binary|io|file|proplists|unicode|calendar|timer|rand|math|persistent_term|sys|crypto|re|gen_server|counters|atomics|erlang)\b" | head -40
echo "## count by file: Elixir.* blocks"
grep -rc --include='*.bs' -E "using :'Elixir\." . 2>/dev/null | grep -v ':0$'
