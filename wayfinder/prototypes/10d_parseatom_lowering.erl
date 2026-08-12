%%% 10d — The ParseAtom<T> lowering, measured
%%%
%%% Evidence for ticket 10 §4. Observed locally on OTP 28 (2026-08-12).
%%%
%%%   erlc 10d_parseatom_lowering.erl
%%%   erl -noshell -pa . -eval "'10d_parseatom_lowering':probe()."
%%%
%%% Ticket 10 §4 claims that `ParseAtom<Outcome>(input)` for
%%% `type Outcome = :zzz_alpha | :zzz_beta;` lowers to a binary match returning
%%% compile-time-known atom literals, and therefore:
%%%
%%%   (a) never calls binary_to_existing_atom and never touches the atom table;
%%%   (b) puts the union's members in the atom chunk by construction, which
%%%       sidesteps the §6.2 hazard for this path.
%%%
%%% This module carries BOTH shapes so the contrast is visible in one atom chunk:
%%% a union whose members appear only in a -type (the hazard), and a union whose
%%% members appear in the lowering (the cure).

-module('10d_parseatom_lowering').
-export([parse/1, type_only/1, probe/0]).

%% The hazard: members appear ONLY in a type, never in value position.
-type unused_set() :: qqq_gamma | qqq_delta.
-spec type_only(unused_set()) -> integer().

type_only(_) -> 0.

%% The lowering: a binary match returning atom literals. No interning call.
-spec parse(binary()) -> zzz_alpha | zzz_beta | nothing.

parse(Bin) ->
    case Bin of
        <<"zzz_alpha">> -> zzz_alpha;
        <<"zzz_beta">>  -> zzz_beta;
        _               -> nothing
    end.

in_chunk(Name, Names) -> lists:member(list_to_binary(Name), Names).

probe() ->
    io:format("parse(<<\"zzz_alpha\">>)         : ~p~n", [parse(<<"zzz_alpha">>)]),
    io:format("parse(<<\"nope\">>)              : ~p~n", [parse(<<"nope">>)]),

    {ok, {_, [{atoms, As}, {imports, Imps}]}} =
        beam_lib:chunks(code:which(?MODULE), [atoms, imports]),
    Names = [atom_to_binary(A) || {_, A} <- As],

    io:format("lowering members in chunk?    : ~p ~p~n",
              [in_chunk("zzz_alpha", Names), in_chunk("zzz_beta", Names)]),
    io:format("type-only members in chunk?   : ~p ~p~n",
              [in_chunk("qqq_gamma", Names), in_chunk("qqq_delta", Names)]),
    io:format("calls binary_to_existing_atom : ~p~n",
              [lists:any(fun({M, F, _}) ->
                             M =:= erlang andalso F =:= binary_to_existing_atom
                         end, Imps)]),
    halt().

%%% Observed output, OTP 28, 2026-08-12:
%%%
%%%   parse(<<"zzz_alpha">>)         : zzz_alpha
%%%   parse(<<"nope">>)              : nothing
%%%   lowering members in chunk?    : true true
%%%   type-only members in chunk?   : false false
%%%   calls binary_to_existing_atom : false
%%%
%%% Both claims hold, and the result is stronger than §4 originally stated.
%%% ParseAtom<T> does not merely AVOID the atom table — it forces T's members
%%% into value position, so applying it to a union CURES that union's §6.2
%%% interning gap. The two lines in the middle are the same module reporting
%%% both behaviours: the atoms the lowering names are interned at load, the
%%% atoms only a -type names are not.
%%%
%%% Note the asymmetry with ToExistingAtom, which cannot do this: it does not
%%% know the permitted set, so it must ask the atom table and must therefore
%%% depend on the §6.2 codegen obligation being discharged.
