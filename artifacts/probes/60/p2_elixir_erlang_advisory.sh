#!/bin/sh
# 60 / probe 2 — Elixir `@moduledoc false` and Erlang `-moduledoc false` (OTP 27+): hidden from docs, callable by anyone?
# Run with env.sh sourced (OTP 28, Elixir 1.18.4). Shows only that the module stays CALLABLE without a warning;
# that it is hidden from generated docs is the documented behaviour, not shown here.
set -u
W=${PROBE_TMP:-$(mktemp -d)}
echo '== Elixir'; elixir --version | tail -1
cat > "$W/e.exs" <<'X'
defmodule Lib.Internal do
  @moduledoc false
  @doc false
  def hidden, do: 1
end
defmodule App do
  def run, do: Lib.Internal.hidden()
end
IO.inspect(App.run(), label: "App.run()")
X
elixir "$W/e.exs" 2>&1 | head -5; echo "exit=$?"
echo '== Erlang'; erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'
cat > "$W/hidden.erl" <<'X'
-module(hidden).
-moduledoc false.
-export([f/0]).
f() -> 1.
X
cat > "$W/app.erl" <<'X'
-module(app).
-export([run/0]).
run() -> hidden:f().
X
(cd "$W" && erlc +warnings_as_errors hidden.erl app.erl && erl -noshell -pa . -eval 'io:format("app:run() = ~p~n",[app:run()]),halt().'; echo "erlc exit=$?")
