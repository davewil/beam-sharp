#!/usr/bin/env bash
# Probe: once a foreign module IS on the code path (ERL_LIBS/rebar3/mix already
# fetched it, exactly ticket 51's measured shape), can bsc derive the OTP
# APPLICATION name from the module atom alone, with no new annotation --
# because both neighbours always lay dependencies out as .../<app>/ebin/<Mod>.beam?
set -euo pipefail
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/req/ebin"
cat > "$WORK/req/Elixir.Req.erl" <<'EOF'
-module('Elixir.Req').
-export([stub/0]).
stub() -> ok.
EOF
erlc -o "$WORK/req/ebin" "$WORK/req/Elixir.Req.erl" >/dev/null

cat > "$WORK/derive.escript" <<EOF
#!/usr/bin/env escript
main(_) ->
    true = code:add_patha("$WORK/req/ebin"),
    Path = code:which('Elixir.Req'),
    io:format("code:which('Elixir.Req')                     = ~s~n", [Path]),
    Ebin = filename:dirname(Path),
    AppDir = filename:dirname(Ebin),
    io:format("app dir one level up from ebin/               = ~s~n", [AppDir]),
    io:format("app name derived purely from directory layout = ~s~n",
               [filename:basename(AppDir)]),
    halt(0).
EOF
chmod +x "$WORK/derive.escript"
"$WORK/derive.escript"

echo
echo "=== Control: what happens if the SAME module atom is asked for and it is NOT on the path? ==="
cat > "$WORK/miss.escript" <<'EOF'
#!/usr/bin/env escript
main(_) ->
    io:format("code:which('Elixir.NoSuchDep') = ~p~n", [code:which('Elixir.NoSuchDep')]),
    halt(0).
EOF
chmod +x "$WORK/miss.escript"
"$WORK/miss.escript"
