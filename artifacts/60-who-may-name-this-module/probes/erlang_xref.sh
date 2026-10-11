#!/usr/bin/env bash
# Probe (c, Erlang): what OTP gives for "who may call me": -export, export_all, erlc, xref.
# One command: ./erlang_xref.sh
source ${BS_ENV:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh}
HERE=$(cd "$(dirname "$0")" && pwd); W=$(mktemp -d)
erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'
echo "### 1. erlc on each module: cross-module calls are never checked by the compiler"
for m in shop_orders shop_reports elsewhere exportall; do echo "-- $m"; erlc +debug_info -o $W $HERE/erlang/$m.erl 2>&1 | grep -i 'warning\|error'; done
echo "   (elsewhere.erl calls shop_orders:hidden/1, a non-exported function: no diagnostic above)"
erl -noshell -pa $W -eval 'io:format("runtime: ~p~n",[catch elsewhere:poke_hidden(1)]),halt().' | cut -c1-120
echo
echo "### 2. xref can ANSWER the question, as a post-build query"
cat > $W/rule.erl <<'EOT'
-module(rule).
-export([run/2]).
%% Friends: #{CalleeModule => [AllowedCallerModules]}.  Returns the violating call edges.
run(Dir, Friends) ->
    {ok,_} = xref:start(s),
    xref:set_default(s, [{verbose,false},{warnings,false}]),
    {ok,_} = xref:add_directory(s, Dir),
    {ok, Edges} = xref:q(s, "XC"),
    xref:stop(s),
    [{From, To} || {{CM,_,_}=From, {Callee,_,_}=To} <- Edges, CM =/= Callee,
                   case maps:find(Callee, Friends) of
                       {ok, Allowed} -> not lists:member(CM, Allowed);
                       error -> false end].
EOT
erlc -o $W $W/rule.erl
erl -noshell -pa $W -eval '
D="'$W'",
io:format("friends(shop_orders)=[shop_reports] -> violations: ~p~n",[rule:run(D,#{shop_orders=>[shop_reports]})]),
io:format("CONTROL friends(shop_orders)=[shop_reports,elsewhere] -> violations: ~p~n",[rule:run(D,#{shop_orders=>[shop_reports,elsewhere]})]),
{ok,_}=xref:start(s2), xref:set_default(s2,[{verbose,false},{warnings,false}]), {ok,_}=xref:add_directory(s2,D),
io:format("xref undefined_function_calls (finds the non-exported call erlc missed): ~p~n",[xref:analyze(s2,undefined_function_calls)]),
io:format("xref {module_use,shop_orders}: ~p~n",[xref:analyze(s2,{module_use,shop_orders})]),
halt().'
