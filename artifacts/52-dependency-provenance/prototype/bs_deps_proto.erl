%%% PROTOTYPE for ticket 52. Not part of the compiler. Checks `[external: K, app: A] using :M {..}` against
%%% the code path of the VM that is compiling, and finds `using :M` with no declaration.
-module(bs_deps_proto).
-export([check/2]).

%% Reqs  :: [{requires, Line, [{external,K}|{app,A}], Mod}]
%% Foreign :: [{Line, Mod}]    every `using :M { .. }` in the module
check(Reqs, Foreign) ->
    Declared = #{M => {L, Attrs} || {requires, L, Attrs, M} <- Reqs, M =/= '*'},
    ModuleWide = [{L, As} || {requires, L, As, '*'} <- Reqs],
    Errs = lists:append([one(L, M, maps:get(M, Declared, undeclared), ModuleWide) || {L, M} <- Foreign])
           ++ lists:append([wide_apps(L, As) || {L, As} <- ModuleWide]),
    lists:foreach(fun({info, _}) -> ok; ({Kind, Msg}) -> io:format(standard_error, "bsc: ~s: ~ts~n", [Kind, Msg]) end, Errs),
    case [E || {error, _} = E <- Errs] of
        [] -> {ok, lists:usort([A || {requires, _, As, _} <- Reqs, {app, A} <- As])};
        _  -> fail
    end.

one(L, M, undeclared, [_ | _] = Wide) ->
    %% option B: the module-wide list must cover the owner of this module (OTP's own libs are implicit)
    Apps = [A || {_, As} <- Wide, {app, A} <- As],
    case code:which(M) of
        non_existing -> [{error, io_lib:format("line ~w: :~w is not on the code path (module-wide apps: ~w)", [L, M, Apps])}];
        W ->
            Owner = owner(W),
            case lists:member(Owner, Apps) orelse is_otp(W) of
                true -> [];
                false -> [{error, io_lib:format("line ~w: :~w belongs to application `~w`, which the module does not list (lists: ~w)", [L, M, Owner, Apps])}]
            end
    end;
one(L, M, undeclared, _) ->
    case code:which(M) of
        non_existing ->
            [{warning, io_lib:format("line ~w: using :~w -- the module is not on the code path of this machine; "
                                     "a call will fail with error:undef (no application is declared)", [L, M])}];
        _ -> []
    end;
one(L, M, {DL, Attrs}, _) ->
    Kind = proplists:get_value(external, Attrs),
    App  = proplists:get_value(app, Attrs),
    W = code:which(M),
    KindErr = case {Kind, is_elixir(M)} of
                  {elixir, false} -> [{error, io_lib:format("line ~w: external: elixir but :~w is not an Elixir.* atom", [DL, M])}];
                  {erlang, true}  -> [{error, io_lib:format("line ~w: external: erlang but :~w is an Elixir.* atom", [DL, M])}];
                  _ -> []
              end,
    KindErr ++
    case App of
        undefined -> [];
        _ ->
            case code:where_is_file(atom_to_list(App) ++ ".app") of
                non_existing ->
                    [{error, io_lib:format("line ~w: application `~w` (for :~w) is not on the code path (ERL_LIBS=~s)",
                                           [DL, App, M, os:getenv("ERL_LIBS", "")])}];
                _ when W =:= non_existing ->
                    [{error, io_lib:format("line ~w: application `~w` is present but does not contain module :~w", [DL, App, M])}];
                _ ->
                    case owner(W) of
                        App -> [];
                        Other -> [{error, io_lib:format("line ~w: module :~w belongs to application `~w`, not `~w`", [DL, M, Other, App])}]
                    end
            end
    end.

is_elixir(M) -> lists:prefix("Elixir.", atom_to_list(M)).

owner(preloaded) -> erts;
owner(Beam) when is_list(Beam) ->
    case filelib:wildcard(filename:join(filename:dirname(Beam), "*.app")) of
        [A] -> list_to_atom(filename:basename(A, ".app"));
        _   -> unknown
    end.

wide_apps(L, As) ->
    [{error, io_lib:format("line ~w: application `~w` is not on the code path (ERL_LIBS=~s)", [L, A, os:getenv("ERL_LIBS", "")])}
     || {app, A} <- As, code:where_is_file(atom_to_list(A) ++ ".app") =:= non_existing].

is_otp(Beam) when is_list(Beam) -> lists:prefix(code:lib_dir(), Beam);
is_otp(_) -> true.
