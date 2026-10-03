#!/usr/bin/env escript
%% p03a: microsecond cost of each presence primitive, hit and miss, N=2000 calls each.
%% Path padded with PAD extra empty ebin dirs to model a big deps tree (rebar3/mix: ~1 dir per dep).
main([PadS]) ->
    Pad = list_to_integer(PadS),
    Root = filename:join("/tmp", "p03pad_" ++ integer_to_list(erlang:unique_integer([positive]))),
    [begin D = filename:join([Root, "dep"++integer_to_list(I)]), ok = filelib:ensure_path(D), code:add_pathz(D) end || I <- lists:seq(1,Pad)],
    io:format("path entries=~p~n", [length(code:get_path())]),
    N = 2000,
    T = fun(Label, F) ->
            F(), %% warm
            {Us, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1,N)] end),
            io:format("  ~-44s ~8.2f us/call~n", [Label, Us/N]) end,
    T("code:which(hit  'Elixir.String')", fun() -> code:which('Elixir.String') end),
    T("code:which(miss 'Elixir.Req')",    fun() -> code:which('Elixir.Req') end),
    T("code:lib_dir(hit  elixir)",        fun() -> code:lib_dir(elixir) end),
    T("code:lib_dir(miss req)",           fun() -> code:lib_dir(req) end),
    T("code:where_is_file(hit  elixir.app)", fun() -> code:where_is_file("elixir.app") end),
    T("code:where_is_file(miss req.app)",    fun() -> code:where_is_file("req.app") end),
    %% application:load is stateful; unload each time to measure the real read
    T("application:load+unload(hit elixir)", fun() -> application:load(elixir), application:unload(elixir) end),
    T("application:load(miss req)",          fun() -> application:load(req) end),
    os:cmd("rm -rf " ++ Root), ok.
