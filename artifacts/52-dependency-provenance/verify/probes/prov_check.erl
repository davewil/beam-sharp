%% PROTOTYPE of the compile-time pass, written outside the compiler. It consumes the AST the
%% patched grammar in 10_grammar_delta.sh produces and the real code server. Diagnostics use the
%% shape bs_diag:message/1 already uses ("FILE:LINE:COL: error: ..." + two-space explanation).
-module(prov_check).
-export([run/3, otp_owned/1, closure/1]).

%% Mode: a (per-block `from :app`) | b (module-level `requires :app`) | c (module on path only)
run(Mode, File, Decls) ->
    Foreign = [{L, M, App} || {foreign, L, M, _S, App} <- Decls] ++
              [{L, M, none} || {foreign, L, M, _S} <- Decls],
    Req = [A || {requires, _, A} <- Decls],
    lists:append([one(Mode, File, F, Req) || F <- lists:sort(Foreign)]) ++
    case Mode of
        b -> lists:append([requires(File, L, A, Foreign) || {requires, L, A} <- Decls]);
        _ -> []
    end.

requires(File, L, A, Foreign) ->
    case code:lib_dir(A) of
        {error, bad_name} ->
            [d(File, L, "`requires :~s`: application `~s` is not on the code path~n"
               "  searched ~s (~p entries). Build it with rebar3 or mix and put its lib directory on ERL_LIBS.",
               [A, A, search_path(), length(code:get_path())])];
        _ ->
            case lists:any(fun({_, M, _}) -> owner(M) =:= {ok, A} end, Foreign) of
                true -> [];
                false -> [d(File, L, "`requires :~s` is not used by any `using` in this module", [A])]
            end
    end.

one(c, File, {L, M, _}, _) ->
    case code:which(M) of
        non_existing -> [d(File, L, "`using ~ts` names a module that is not on the code path~n"
                           "  searched ~s (~p entries). Put the directory holding its ebin on ERL_LIBS.",
                           [q(M), search_path(), length(code:get_path())])];
        _ -> []
    end;
one(a, File, {L, M, none}, _) ->
    case otp_owned(M) of
        true -> [];
        {false, Where} ->
            [d(File, L, "`using ~ts` is not an OTP module and names no application~n"
               "  it lives in ~ts. Write `using ~ts from :<app>` so the source says what it needs.",
               [q(M), Where, q(M)])]
    end;
one(a, File, {L, M, App}, _) -> verify(File, L, M, App);
one(b, File, {L, M, _}, Req) ->
    case otp_owned(M) of
        true -> [];
        {false, _} ->
            case owner(M) of
                {ok, App} ->
                    case lists:member(App, Req) of
                        true -> verify(File, L, M, App);
                        false -> [d(File, L, "`using ~ts` is in application `~s`, which this module does not require~n"
                                    "  add `requires :~s` to index.bs", [q(M), App, App])]
                    end;
                {noapp, Where} -> [d(File, L, "`using ~ts` is on the path at ~ts, outside any application directory~n"
                                     "  no `requires` can name it; accepted unverified.", [q(M), Where])];
                non_existing ->
                    case [A || A <- Req, code:lib_dir(A) =:= {error, bad_name}] of
                        [] -> [d(File, L, "`using ~ts` is in none of the required applications (~s)~n"
                                 "  searched ~s", [q(M), lists:join(", ", [atom_to_list(A) || A <- Req]), search_path()])];
                        _ -> []   % covered by the missing-application diagnostic on the `requires` line
                    end
            end
    end.

verify(File, L, M, App) ->
    case code:lib_dir(App) of
        {error, bad_name} ->
            [d(File, L, "`using ~ts` needs application `~s`, which is not on the code path~n"
               "  searched ~s (~p entries). Build it with rebar3 or mix and put its lib directory on ERL_LIBS.",
               [q(M), App, search_path(), length(code:get_path())])];
        Dir ->
            case owner(M) of
                {ok, App} -> [];
                {ok, Other} -> [d(File, L, "`using ~ts` is in application `~s`, not `~s`~n"
                                  "  say `from :~s`", [q(M), Other, App, Other])];
                {noapp, Where} -> [d(File, L, "`using ~ts` is on the path at ~ts, outside any application directory~n"
                                     "  `from :~s` cannot be checked; it is accepted unverified.", [q(M), Where, App])];
                non_existing -> [d(File, L, "application `~s` is on the path (~ts) but has no module `~ts`", [App, Dir, M])]
            end
    end.

%% module -> application, by path shape (probe 04 measured where this holds)
owner(M) ->
    case code:which(M) of
        non_existing -> non_existing;
        preloaded -> {ok, erts};
        F when is_list(F) ->
            case lists:reverse(filename:split(F)) of
                [_, "ebin", AppDir | _] -> {ok, list_to_atom(strip_vsn(AppDir))};
                _ -> {noapp, filename:dirname(F)}
            end
    end.
strip_vsn(D) ->
    case re:run(D, "^(.*)-[0-9][0-9.]*$", [{capture, [1], list}]) of
        {match, [N]} -> N; nomatch -> D
    end.

%% "OTP's own": the module's application directory sits under code:root_dir()
otp_owned(M) ->
    case code:which(M) of
        preloaded -> true;
        non_existing -> {false, "nowhere on the path"};
        F -> case lists:prefix(code:root_dir(), F) of true -> true; false -> {false, F} end
    end.

%% transitive `applications` closure from .app files; returns {Present, Missing}
closure(App) -> closure([App], [], []).
closure([], Seen, Miss) -> {lists:reverse(Seen), lists:usort(Miss)};
closure([A | Rest], Seen, Miss) ->
    case lists:member(A, Seen) orelse lists:member(A, Miss) of
        true -> closure(Rest, Seen, Miss);
        false ->
            case code:lib_dir(A) of
                {error, _} -> closure(Rest, Seen, [A | Miss]);
                Dir ->
                    Deps = case file:consult(filename:join([Dir, "ebin", atom_to_list(A) ++ ".app"])) of
                               {ok, [{application, A, P}]} -> proplists:get_value(applications, P, []);
                               _ -> []
                           end,
                    closure(Rest ++ Deps, [A | Seen], Miss)
            end
    end.

q(M) -> lists:flatten(io_lib:format(":~tp", [M])).

search_path() -> case os:getenv("ERL_LIBS") of false -> "ERL_LIBS (unset)"; V -> "ERL_LIBS=" ++ V end.

d(File, {L, C}, Fmt, Args) -> lists:flatten(io_lib:format("~s:~p:~p: error: " ++ Fmt ++ "~n", [File, L, C | Args])).
