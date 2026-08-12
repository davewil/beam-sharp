%%% 10b — What actually lands in a module's atom chunk
%%%
%%% Evidence for ticket 10 §6.2 and §6.3. Observed locally on OTP 28 (2026-08-12).
%%%
%%%   erlc 10b_atom_interning.erl && erl -noshell -pa . -s '10b_atom_interning' probe
%%%
%%% Two findings, both about the gap between what the source says and what the
%%% atom table holds:
%%%
%%%   1. An atom appearing ONLY in a -type/-spec is NOT in the atom chunk, so
%%%      binary_to_existing_atom/1 rejects it. Under ticket 09's erased types
%%%      that would make a safe converter reject values the type system permits.
%%%
%%%   2. erlc CONSTANT-FOLDS binary_to_atom/1 on a literal binary. The atom lands
%%%      in the atom chunk and is interned at module load, before the call runs.
%%%      So minting from a literal is indistinguishable from writing the atom.
%%%      The atom-table hazard is only ever a RUNTIME-BUILT string.
%%%
%%% Probe hygiene: atom names are assembled from character codes, never written
%%% as literals, because mentioning an atom anywhere in this file would intern it
%%% and silently invalidate the measurement. A first draft of this probe did
%%% exactly that (`lists:member('runtime_built_atom', ...)`) and reported both
%%% atoms interned.

-module('10b_atom_interning').
-export([probe/0, typed_fun/1, mint_from_literal/0, mint_from_runtime/1]).

-type only_in_a_type() :: never_written_as_a_value | nor_is_this_one.
-spec typed_fun(only_in_a_type()) -> integer().

typed_fun(_) -> 1.

%% erlc folds this at compile time: the atom is in the atom chunk.
mint_from_literal() -> erlang:binary_to_atom(<<"aaa_literal_arg_zzz">>).

%% Not foldable: the atom is minted when this actually runs.
mint_from_runtime(B) -> erlang:binary_to_atom(B).

interned(B) ->
    try binary_to_existing_atom(B) of
        A -> {interned, A}
    catch
        _:_ -> not_interned
    end.

probe() ->
    %% NOTE: typed_fun/1 is deliberately never called with a literal from its own
    %% type. Doing so puts the atom in value position and interns it — a second
    %% draft of this probe did exactly that and reported the type-only atom
    %% interned, which is the failure this file exists to demonstrate.

    %% Built from codes so this file never mentions them as atoms.
    TypeOnly = list_to_binary("never_written_as_a_value"),
    Literal  = list_to_binary("aaa_literal_arg_zzz"),
    Runtime  = list_to_binary("bbb_runtime_only_zzz"),

    io:format("type-position only, never a value : ~p~n", [interned(TypeOnly)]),
    io:format("literal arg to binary_to_atom     : ~p~n", [interned(Literal)]),
    io:format("runtime-built, before the call    : ~p~n", [interned(Runtime)]),
    _ = mint_from_runtime(Runtime),
    io:format("runtime-built, after the call     : ~p~n", [interned(Runtime)]),

    {ok, {_, [{atoms, As}]}} = beam_lib:chunks(code:which(?MODULE), [atoms]),
    Names = [atom_to_binary(A) || {_, A} <- As],
    io:format("type-only in atom chunk?          : ~p~n", [lists:member(TypeOnly, Names)]),
    io:format("literal-arg in atom chunk?        : ~p~n", [lists:member(Literal, Names)]),
    io:format("runtime-built in atom chunk?      : ~p~n", [lists:member(Runtime, Names)]),
    halt().

%%% Observed output, OTP 28, 2026-08-12:
%%%
%%%   type-position only, never a value : not_interned
%%%   literal arg to binary_to_atom     : {interned,aaa_literal_arg_zzz}
%%%   runtime-built, before the call    : not_interned
%%%   runtime-built, after the call     : {interned,bbb_runtime_only_zzz}
%%%   type-only in atom chunk?          : false
%%%   literal-arg in atom chunk?        : true
%%%   runtime-built in atom chunk?      : false
