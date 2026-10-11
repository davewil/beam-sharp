#!/usr/bin/env bash
# Probe (d, Gleam): what does the real Gleam compiler emit for a private fn taking a record
# (custom type) / an Int, and for the exported ones?  Gleam 1.19 writes abstract code
# (scope.abstr, a term_to_binary list of forms), not .erl, so we pretty-print it with erl_pp.
cd "$(dirname "$0")/gl"
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
gleam build --target erlang 2>&1 | tail -2
erl -noshell -eval '
 {ok,B}=file:read_file("build/dev/erlang/scope/_gleam_artefacts/scope.abstr"),
 Forms = binary_to_term(B),
 [io:format("~s~n",[erl_pp:form(X)]) || X <- Forms, element(1,X)=:=function],
 halt().'
echo "--- count of guards (when ...) in the emitted functions:"
erl -noshell -eval '
 {ok,B}=file:read_file("build/dev/erlang/scope/_gleam_artefacts/scope.abstr"),
 Forms = binary_to_term(B),
 F = fun F([_|_]=L) -> lists:sum([F(X) || X <- L]);
         F({clause,_,_,G,Body}) -> (case G of [] -> 0; _ -> 1 end) + F(Body);
         F(T) when is_tuple(T) -> F(tuple_to_list(T));
         F(_) -> 0 end,
 Gs = [{N, F(Cs)} || {function,_,N,_,Cs} <- Forms],
 io:format("guarded clauses (any depth) per function: ~p~n",[Gs]), halt().'
