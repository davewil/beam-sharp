#!/usr/bin/env escript
%% Run: escript p2b_xref_needs_debug_info.escript
%% Observes whether xref silently reports no call edges for beams built without debug_info.
main(_) ->
    D = filename:join(os:getenv("TMPDIR","/tmp"), "p2b_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(filename:join(D,"x")),
    ok = file:write_file(filename:join(D,"aa.erl"), "-module(aa).\n-export([f/0]).\nf() -> bb:h().\n"),
    ok = file:write_file(filename:join(D,"bb.erl"), "-module(bb).\n-export([h/0]).\nh() -> ok.\n"),
    Count = fun(Opts, Tag) ->
        [{ok,_} = compile:file(filename:join(D,F), [{outdir,D}|Opts]) || F <- ["aa.erl","bb.erl"]],
        {ok,_} = xref:start(Tag), {ok,_} = xref:add_directory(Tag, D),
        {ok, E} = xref:q(Tag, "ME"), xref:stop(Tag), length(E) end,
    NoDbg = Count([], x1), Dbg = Count([debug_info], x2),
    io:format("module edges without debug_info: ~p ; with debug_info: ~p~n", [NoDbg, Dbg]),
    case {NoDbg, Dbg} of {0, 1} -> ok; _ -> io:format("FAIL: unexpected~n"), halt(1) end.
