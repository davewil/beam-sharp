#!/usr/bin/env bash
# (f) Can a provenance annotation survive into the .beam?
set -u; D=$(mktemp -d); cd "$D"
cat > m.erl <<'X'
-module(m).
-export([f/0]).
-app(req).
-external([{elixir,req}]).
-vsn("1").
f() -> ok.
X
erlc m.erl; echo "erlc exit=$?"
erl -noshell -eval '{ok,{m,[{attributes,A}]}}=beam_lib:chunks("m.beam",[attributes]), io:format("attributes: ~p~n",[A]), io:format("m:module_info(attributes): ~p~n",[(fun()-> code:load_abs("m"), m:module_info(attributes) end)()]), halt().'
echo "## same via the Abstract Format (what bs_emit would hand to compile:file from_abstr)"
erl -noshell -eval '
F=[{attribute,1,module,m},{attribute,1,export,[{f,0}]},{attribute,1,app,req},{attribute,1,external,[{elixir,req}]},{function,1,f,0,[{clause,1,[],[],[{atom,1,ok}]}]}],
{ok,m,B}=compile:forms(F,[]), {ok,{m,[{attributes,A}]}}=beam_lib:chunks(B,[attributes]), io:format("~p~n",[A]), halt().'
