#!/usr/bin/env escript
%% p3: F31's predicate (T | F == T  iff  F subtype-of T) evaluated with OTP's
%% erl_types (dialyzer-5.0.5) as the set-theoretic instrument. NOT B#'s algebra
%% (bs_types.erl is not runnable here) and NOT Elixir's Descr (1.14 has none):
%% the table below is a reproduction of ticket 15 s1 / F31 S1-S11 on a third
%% algebra, labelled as such in the brief.
%% Run: escript p3_absorption_algebra.escript > p3_absorption_algebra.out
%% Exit 1 if the cofinite-only rule (d) turns out to agree with F31's predicate
%% on every row (then (d) would not be refuted).
-mode(compile).
main(_) ->
    A   = erl_types:t_any(),
    N   = erl_types:t_atom(nothing),
    Ok  = erl_types:t_atom(ok),
    Int = erl_types:t_integer(),
    At  = erl_types:t_atom(),
    Bin = erl_types:t_binary(),
    Err = fun(E) -> erl_types:t_tuple([erl_types:t_atom(error), E]) end,
    Opt = fun(T) -> {T, N} end,                 %% option<T>  = T | :nothing
    Res = fun(T, E) -> {T, Err(E)} end,         %% result<T,E> = T | (:error, E)
    OptOpt = erl_types:t_sup(Int, N),
    Rows = [
      {"option<int>",                    Opt(Int)},
      {"option<atom>",                   Opt(At)},
      {"option<term>",                   Opt(A)},
      {"option<option<int>>",            Opt(OptOpt)},
      {"option<bool>",                   Opt(erl_types:t_sup(erl_types:t_atom(true), erl_types:t_atom(false)))},
      {"result<int, binary>",            Res(Int, Bin)},
      {"result<int, term>      [E = term]", Res(Int, A)},
      {"result<atom, term>     [E = term]", Res(At, A)},
      {"result<term, binary>   [T = term]", Res(A, Bin)},
      {"result<term, term>",             Res(A, A)},
      {"result<(atom,binary),binary>",   Res(erl_types:t_tuple([At, Bin]), Bin)},
      {"result<tuple, atom>",            Res(erl_types:t_tuple(), At)},
      {"result<result<int,term>, term>  [nested, E = term]", Res(erl_types:t_sup(Int, Err(A)), A)},
      {"result<result<int,atom>, binary> [nested, distinct E]", Res(erl_types:t_sup(Int, Err(At)), Bin)},
      {"(:ok, term) | :absent  [48 tagged]", {erl_types:t_tuple([Ok, A]), erl_types:t_atom(absent)}}
    ],
    Cofinite = fun(T) -> erl_types:t_is_subtype(erl_types:t_atom(), T) end,  %% T contains all atoms
    Results = [begin
        Absorbed = erl_types:t_is_subtype(F, T),
        Sup = erl_types:t_to_string(erl_types:t_sup(T, F)),
        io:format("~-56s success=~-34s failure=~-22s absorbed=~-5s cofinite-atom-top=~s~n",
                  [Name, erl_types:t_to_string(T), erl_types:t_to_string(F), Absorbed, Cofinite(T)]),
        io:format("~-56s T|F prints as ~s~n", ["", Sup]),
        {Name, Absorbed, Cofinite(T)}
      end || {Name, {T, F}} <- [{N0, case P of {T0, F0} -> {T0, F0} end} || {N0, P} <- Rows]],
    %% rule (d) misses = rows F31's predicate refuses that a cofinite-top check would let through
    Disagree = [Nm || {Nm, true, false} <- Results],
    io:format("~nrows F31's predicate refuses (absorbed=true) with NO cofinite atom top (rule d would accept):~n  ~p~n", [Disagree]),
    case Disagree of [] -> io:format("RULE (d) NOT REFUTED~n"), halt(1);
                     _  -> io:format("RULE (d) REFUTED by ~p row(s)~n", [length(Disagree)]), halt(0) end.
