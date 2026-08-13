%%% 20c — Does the BEAM's type machinery have integer intervals?
%%%
%%% Ticket 08's rule: "the checker credits any condition it can translate into
%%% a type operation — `not :shipped` -> set difference, `n > 1` -> interval
%%% refinement, `HasSku(lines, sku)` -> nothing." It named interval refinement
%%% without checking whether the platform supplies one.
%%%
%%% It does not. erl_types quantises every range onto a fixed ladder of named
%%% Erlang types — neg_integer, pos_integer, non_neg_integer, byte (1..255),
%%% char (1..1114111), integer — and widens anything else to the nearest.
%%%
%%% This is the SAME failure as 20a's binary union, in a second domain:
%%% over-approximation on the way IN, which is always sound for a success-typing
%%% tool and never sound for a pessimistic one.
%%%
%%% Run: erlc -o . 20c_integer_intervals.erl
%%%      erl -noshell -pa . -eval "'20c_integer_intervals':run(),halt()."
%%%
%%% Measured on OTP 28.5, 2026-08-13.

-module('20c_integer_intervals').
-export([run/0]).

run() ->
    small_ranges(),
    quantisation(),
    unbounded(),
    the_fib_artefact(),
    ok.

%% Small ranges are expanded to explicit unions and behave correctly.
small_ranges() ->
    io:format("~n=== small ranges: expanded, and correct ===~n"),
    I = erl_types:t_from_range(1, 3),
    show("1..3            ", I),                                        % 1 | 2 | 3
    show("  minus 1       ", erl_types:t_subtract(I, erl_types:t_integer(1))).  % 2 | 3

%% Anything past the expansion limit is snapped to a named type.
quantisation() ->
    io:format("~n=== ranges past the expansion limit: SNAPPED ===~n"),
    show("t_from_range(1,10)     ", erl_types:t_from_range(1, 10)),
        % => 1 | 2 | ... | 10          (still expanded)
    show("t_from_range(5,20)     ", erl_types:t_from_range(5, 20)),
        % => 1..255                    (snapped to byte())
    show("t_from_range(1,1000)   ", erl_types:t_from_range(1, 1000)),
        % => 1..1114111                (snapped to char())
    show("t_from_range(500,2000) ", erl_types:t_from_range(500, 2000)),
        % => 1..1114111                (same)
    show("  (1..1000) - (500..2000)", erl_types:t_subtract(erl_types:t_from_range(1,1000),
                                                           erl_types:t_from_range(500,2000))).
        % => none()   -- both widened to the same type, so subtraction empties.
        %    A *wrong* answer produced by a *sound* over-approximation.

%% Unbounded ends collapse the hardest.
unbounded() ->
    io:format("~n=== unbounded ends ===~n"),
    show("t_from_range(neg_inf,1)", erl_types:t_from_range(neg_inf, 1)),
        % => integer()      -- the bound is simply gone
    show("t_from_range(2,pos_inf)", erl_types:t_from_range(2, pos_inf)),
        % => pos_integer()  -- widened DOWN: now admits 1
    io:format("(n>5) <: (n>0) ? ~p     (both are pos_integer(), so mutually subtype)~n",
              [erl_types:t_is_subtype(erl_types:t_from_range(6, pos_inf),
                                      erl_types:t_from_range(1, pos_inf))]),
    io:format("(n>0) <: (n>5) ? ~p~n",
              [erl_types:t_is_subtype(erl_types:t_from_range(1, pos_inf),
                                      erl_types:t_from_range(6, pos_inf))]).

%% Ticket 11 filed the `Fib` debt here. Running it against erl_types produces
%% "exhaustive: true" — but by accident, not by reasoning: neg_inf..1 became
%% integer(), so integer() - integer() emptied. The checker never saw `n <= 1`.
%%
%% Recording it because a future session re-running this probe would otherwise
%% read the result as a pass.
the_fib_artefact() ->
    io:format("~n=== the Fib artefact — a correct-by-accident result ===~n"),
    Int = erl_types:t_integer(),
    LE1 = erl_types:t_from_range(neg_inf, 1),
    show("declared int          ", Int),   % integer()
    show("clause 1 (n <= 1)     ", LE1),   % integer()   <-- the bound is gone
    R = erl_types:t_subtract(Int, LE1),
    show("residual for clause 2 ", R),     % none()
    io:format("  looks exhaustive: ~p, but nothing reasoned about `n <= 1`~n",
              [erl_types:t_is_none(R)]).

show(Label, T) -> io:format("~s = ~s~n", [Label, erl_types:t_to_string(T)]).
