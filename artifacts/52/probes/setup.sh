#!/usr/bin/env bash
# Recreates every fixture the probes use, under /tmp.  Idempotent.  No network (hex.pm is refused by the proxy; see brief).
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MIX_HOME=/tmp/mixdeps52b/.mix HEX_HOME=/tmp/mixdeps52b/.hex

# 1. A real mix-built Elixir application and two consumer projects (stand-in for Req; hex is unreachable).
mkdir -p /tmp/mixdeps52b/libdep/lib /tmp/mixdeps52b/consumer/lib /tmp/mixdeps52b/consumer_undeclared/lib
cat > /tmp/mixdeps52b/libdep/mix.exs <<'X'
defmodule Libdep.MixProject do
  use Mix.Project
  def project, do: [app: :libdep, version: "2.3.1", elixir: "~> 1.14", deps: []]
  def application, do: [extra_applications: [:logger]]
end
X
cat > /tmp/mixdeps52b/libdep/lib/libdep.ex <<'X'
defmodule Libdep do
  def hello(name), do: "hello " <> name
  def hello!(name), do: "hello! " <> name
  def total(xs), do: Enum.sum(xs)
end
defmodule Libdep.Extra do
  def two, do: 2
end
X
cat > /tmp/mixdeps52b/consumer/mix.exs <<'X'
defmodule Consumer.MixProject do
  use Mix.Project
  def project, do: [app: :consumer, version: "0.1.0", elixir: "~> 1.14", deps: [{:libdep, path: "../libdep"}]]
  def application, do: [extra_applications: [:logger]]
end
X
echo 'defmodule Consumer do def x, do: Libdep.hello("c") end' > /tmp/mixdeps52b/consumer/lib/consumer.ex
cp "$HERE/neighbours/mix_undeclared/mix.exs" /tmp/mixdeps52b/consumer_undeclared/mix.exs
cp "$HERE/neighbours/mix_undeclared/consumer_u.ex" /tmp/mixdeps52b/consumer_undeclared/lib/consumer_u.ex
( cd /tmp/mixdeps52b/consumer && mix deps.compile libdep --force >/dev/null 2>&1 )
test -f /tmp/mixdeps52b/consumer/_build/dev/lib/libdep/ebin/libdep.app

# 2. Two versions of one OTP-style application side by side (rebar3 / ERL_LIBS shape).
mkdir -p /tmp/fakelibs52/acme-1.2.0/ebin /tmp/fakelibs52/acme-1.3.0/ebin /tmp/fakelibs52/src12 /tmp/fakelibs52/src13
for v in 1.2.0 1.3.0; do
  echo "{application,acme,[{description,\"acme\"},{vsn,\"$v\"},{modules,[acme_mod]},{registered,[]},{applications,[kernel,stdlib]}]}." > /tmp/fakelibs52/acme-$v/ebin/acme.app
done
printf -- '-module(acme_mod).\n-export([version/0]).\nversion() -> "1.2.0".\n' > /tmp/fakelibs52/src12/acme_mod.erl
printf -- '-module(acme_mod).\n-export([version/0, only_in_130/0]).\nversion() -> "1.3.0".\nonly_in_130() -> yes.\n' > /tmp/fakelibs52/src13/acme_mod.erl
erlc -o /tmp/fakelibs52/acme-1.2.0/ebin /tmp/fakelibs52/src12/acme_mod.erl
erlc -o /tmp/fakelibs52/acme-1.3.0/ebin /tmp/fakelibs52/src13/acme_mod.erl

# 3. An OTP application that needs its process started.
mkdir -p /tmp/fakelibs52b/ticker-0.1.0/ebin /tmp/fakelibs52b/src
cat > /tmp/fakelibs52b/src/ticker.erl <<'X'
-module(ticker).
-behaviour(application).
-behaviour(gen_server).
-export([start/2, stop/1, get/0, init/1, handle_call/3, handle_cast/2]).
start(_, _) -> gen_server:start_link({local, ticker_srv}, ?MODULE, 41, []).
stop(_) -> ok.
get() -> gen_server:call(ticker_srv, get).
init(N) -> {ok, N}.
handle_call(get, _, N) -> {reply, N + 1, N}.
handle_cast(_, N) -> {noreply, N}.
X
erlc -o /tmp/fakelibs52b/ticker-0.1.0/ebin /tmp/fakelibs52b/src/ticker.erl
echo '{application,ticker,[{description,"a dependency with a process"},{vsn,"0.1.0"},{modules,[ticker]},{registered,[ticker_srv]},{mod,{ticker,[]}},{applications,[kernel,stdlib]}]}.' > /tmp/fakelibs52b/ticker-0.1.0/ebin/ticker.app

# 4. 200 empty application directories, to lengthen the code path.
for i in $(seq 1 200); do mkdir -p /tmp/manylibs52/app$i-1.0.0/ebin; done

# 5. The compiler, and the scratch parser.
"$HERE/build-bsc.sh" >/dev/null
"$HERE/build_parser_b.sh" >/dev/null 2>&1
echo "setup ok"
