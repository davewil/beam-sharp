%% PROTOTYPE 12d -- what the BEAM calls the bottom type.
%%
%% Ticket 12. Evidence for spelling beam-sharp's bottom `none`.
%% Provenance: local, OTP 28.
%%
%% Reproduce:  erlc 12d_bottom_type.erl
%%
%% Observed: none() and no_return() compile; never() does not --
%%
%%     12d_bottom_type.erl:24:26: type never() undefined
%%
%% And Erlang's own type machinery prints the empty type as `none()`:
%%
%%     erl -noshell -eval 'N = erl_types:t_none(),
%%       io:format("~s ~p~n",[erl_types:t_to_string(N), erl_types:t_is_none(N)]),
%%       halt().'
%%     none() true
%%
%% The decision: `none`, mirroring ticket 11's override of the borrow heuristic
%% for `term`. TypeScript's `never` is the tier-1 borrow and was rejected for
%% the same two reasons `unknown` was: the bottom here is a SET you take
%% complements of, not an epistemic state, and it matches the emitted -spec.
%% Taking `never` while the top is `term` would name one lattice from two
%% heritages, in the one place where both names are always read together.
%%
%% Known false friend, to be stated in the spec: `none` (a type with no values)
%% versus the prelude's `:nothing` (a value meaning absence, ticket 10 §5).
%% Same treatment as `as` meaning C#'s checked conversion rather than TS's
%% unchecked assertion.
%%
%% Uncomment nope/1 to reproduce the failure.

-module('12d_bottom_type').
-export([boom/1, boom2/1]).

-spec boom(integer()) -> none().
boom(_) -> erlang:error(bad).

-spec boom2(integer()) -> no_return().
boom2(_) -> erlang:error(bad).

%% -spec nope(integer()) -> never().     % type never() undefined
%% nope(_) -> erlang:error(bad).
