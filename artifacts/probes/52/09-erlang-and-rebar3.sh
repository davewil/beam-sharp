#!/usr/bin/env bash
# CLAIM (mine): in the Erlang world the `applications` key of the .app is where "what I need" lives; a
# listed-but-absent app fails at START, by NAME; a called-but-unlisted app fails at the CALL as error:undef;
# and rebar3 compile does NOT cross-check the two, while rebar3 xref does flag the undefined remote.
# REFUTED IF: rebar3 compile errors/warns about an `applications` entry that is absent, or about the unlisted call;
#   or ensure_all_started on an absent listed app yields undef rather than a named error; or rebar3 xref is silent.
. "$(dirname "$0")/lib.sh"
export HOME=$WORK/rhome REBAR_CACHE_DIR=$WORK/rcache; mkdir -p "$HOME"
P=$WORK/hostapp; rm -rf "$P"; cp -r "$ROOT/fixtures/rebar3app" "$P"; cd "$P"
unset ERL_LIBS
clean() { sed 's/\x1b\[[0-9;]*m//g; /^Setting httpc/d; /^ \{20,\}"/d'; }   # strip colour + the sandbox proxy banner
echo "### 1. rebar3 compile + xref: calls 'Elixir.MyLib':new/1, .app.src applications = [kernel, stdlib], mylib absent"
rebar3 compile 2>&1 | clean; echo "[compile exit=${PIPESTATUS[0]}]"
rebar3 xref 2>&1 | clean; echo "[xref exit=${PIPESTATUS[0]}]"
echo "### 2. start it: no mylib listed, none present -> starts fine, dies at the call"
erl -noshell -pa _build/default/lib/hostapp/ebin -eval 'io:format("start: ~p~n",[application:ensure_all_started(hostapp)]), io:format("call: ~p~n",[catch hostapp:go()]), halt().'
echo "### 3. list a dependency that is absent: rebar3 compile accepts it?"
sed -i 's/{applications, \[kernel, stdlib\]}/{applications, [kernel, stdlib, mylib]}/' src/hostapp.app.src
rebar3 compile 2>&1 | clean; echo "[compile exit=${PIPESTATUS[0]}]"
erl -noshell -pa _build/default/lib/hostapp/ebin -eval 'io:format("start: ~p~n",[application:ensure_all_started(hostapp)]), halt().'
echo "### 4. same listing, dependency present on ERL_LIBS"
ERL_LIBS=$MYLIBS:$SCRATCH/env/lib/elixir/lib erl -noshell -pa _build/default/lib/hostapp/ebin -eval 'io:format("start: ~p~n",[element(1,application:ensure_all_started(hostapp))]), io:format("call: ~p~n",[hostapp:go()]), halt().'
