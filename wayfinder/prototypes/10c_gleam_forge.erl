%%% 10c — Forging Gleam values from raw Erlang
%%%
%%% Evidence for ticket 10 §7 and ticket 06's third outcome. Observed locally on
%%% Gleam 1.18.1 / OTP 28 (2026-08-12). Companion to 10c_gleam_atoms.gleam.
%%%
%%%   cd gleamprobe && gleam build
%%%   EBIN=$(find build -name gleamprobe.beam -exec dirname {} \; | head -1)
%%%   erlc -o /tmp 10c_gleam_forge.erl
%%%   erl -noshell -pa "$EBIN" -pa /tmp -s '10c_gleam_forge' main
%%%
%%% The map records Gleam's stance on foreign callers as "inferred from the
%%% absence of guard emission" rather than observed. This observes it.

-module('10c_gleam_forge').
-export([main/0]).

t(F) ->
    try F() of
        V -> {ok, V}
    catch
        C:E -> {caught, C, element(1, E)}
    end.

main() ->
    io:format("describe(red) from raw Erlang  : ~p~n",
              [t(fun() -> gleamprobe:describe(red) end)]),
    io:format("describe(purple) forged        : ~p~n",
              [t(fun() -> gleamprobe:describe(purple) end)]),
    io:format("area({circle, 2.0}) forged     : ~p~n",
              [t(fun() -> gleamprobe:area({circle, 2.0}) end)]),
    io:format("area({circle, <<\"str\">>})      : ~p~n",
              [t(fun() -> gleamprobe:area({circle, <<"str">>}) end)]),
    io:format("flag() =:= true                : ~p~n", [gleamprobe:flag() =:= true]),
    io:format("nothing() =:= nil              : ~p~n", [gleamprobe:nothing() =:= nil]),
    halt().

%%% Observed output, 2026-08-12:
%%%
%%%   describe(red) from raw Erlang  : {ok,<<"r">>}
%%%   describe(purple) forged        : {caught,error,case_clause}
%%%   area({circle, 2.0}) forged     : {ok,2.0}
%%%   area({circle, <<"str">>})      : {ok,<<"str">>}
%%%   flag() =:= true                : true
%%%   nothing() =:= nil              : true
%%%
%%% Line 1: a raw Erlang atom is accepted as a nominal Gleam `Colour`. Nothing
%%% was constructed; there is no construction discipline to violate. This is
%%% ticket 09 §5's argument, previously evidenced only against Elixir structs
%%% (prototypes/16a_elixir_protocol_dispatch.exs), now evidenced against the
%%% BEAM's flagship statically typed language.
%%%
%%% Line 4 is the load-bearing one. `-spec area(shape()) -> float()` RETURNED A
%%% BINARY. No crash, no coercion, no wrong number — a wrong *kind of term*
%%% leaving a typed function. That is ticket 06's third outcome, silent
%%% unsoundness, demonstrated in the language beam-sharp differentiates from.
%%% Gleam emits no guard, so nothing tests the payload; the clause matched on
%%% the tuple tag `circle` alone and handed the payload straight back.
%%%
%%% Note the contrast between lines 2 and 4. Forging the TAG is caught, because
%%% the tag is the only thing a clause head tests. Forging the PAYLOAD is not.
%%% Any defence has to check where a term becomes a typed value — ticket 21's
%%% conclusion, and ticket 18's job.
