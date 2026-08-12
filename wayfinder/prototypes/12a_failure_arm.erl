%% PROTOTYPE 12a -- what the compiler-generated failure arm actually buys.
%%
%% Ticket 12. Evidence for the decision NOT to omit the failure arm when the
%% checker proves exhaustiveness. Provenance: local, OTP 28.
%%
%% Reproduce:
%%   erlc +to_core 12a_failure_arm.erl     % see the compiler-generated arm
%%   erlc 12a_failure_arm.erl              % baseline .beam
%%
%% partial/1 lowers to a case with a THIRD clause the compiler inserted:
%%
%%     ( <_1> when 'true' ->
%%           ( primop 'match_fail'
%%                 (( {'function_clause',_1} -| [{'function',{'partial',1}}] ))
%%             -| [{'function',{'partial',1}}] )
%%       -| ['compiler_generated'] )
%%
%% total/1 lowers to `fun (_0) -> 1` -- no case expression at all. That is the
%% key asymmetry: erlc omits the arm only when coverage is proved over ALL
%% TERMS, so nothing can defy it. beam-sharp's exhaustiveness is over the
%% DECLARED TYPE, a strictly smaller set, and ticket 06 found values outside it
%% arrive through eight channels. The two omissions are not the same operation.

-module('12a_failure_arm').
-export([partial/1, total/1]).

%% clauses cover only two atoms -- erlc inserts a match_fail arm
partial(a) -> 1;
partial(b) -> 2.

%% clauses cover every term -- erlc removes the dispatch entirely
total(_) -> 1.
