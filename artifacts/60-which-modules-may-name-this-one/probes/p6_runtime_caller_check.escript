#!/usr/bin/env escript
%% Run: escript p6_runtime_caller_check.escript
%% Question: could "who may call" be enforced at RUN time (guard emitted into the callee) instead of
%% compile time? Observes (a) whether the caller module is visible via current_stacktrace when the call
%% is a tail call vs a non-tail call, (b) ns/call cost of looking.
main(_) ->
    Dir = filename:join(os:getenv("TMPDIR","/tmp"), "p6_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(filename:join(Dir,"x")),
    L = fun(Name, Src) -> F = filename:join(Dir, Name ++ ".erl"), ok = file:write_file(F, Src),
            {ok, M, B} = compile:file(F, [binary]), {module, M} = code:load_binary(M, F, B) end,
    L("callee6", "-module(callee6).\n-export([who/0, plain/0]).\nplain() -> ok.\n"
                 "who() -> {current_stacktrace, St} = process_info(self(), current_stacktrace),\n  [M || {M,_,_,_} <- St].\n"),
    L("caller_tail", "-module(caller_tail).\n-export([go/0]).\ngo() -> callee6:who().\n"),
    L("caller_body", "-module(caller_body).\n-export([go/0]).\ngo() -> X = callee6:who(), {x, X}.\n"),
    Tail = caller_tail:go(),
    {x, Body} = caller_body:go(),
    io:format("tail call   : modules on stack seen by callee = ~p~n", [Tail]),
    io:format("non-tail    : modules on stack seen by callee = ~p~n", [Body]),
    TailSeen = lists:member(caller_tail, Tail),
    BodySeen = lists:member(caller_body, Body),
    io:format("caller visible in tail position: ~p ; in body position: ~p~n", [TailSeen, BodySeen]),
    Iters = 200000,
    Bench = fun(F) -> {T,_} = timer:tc(fun() -> lists:foreach(fun(_) -> F() end, lists:seq(1, Iters)) end), T*1000/Iters end,
    Plain = Bench(fun() -> callee6:plain() end),
    Guard = Bench(fun() -> callee6:who() end),
    io:format("ns/call: plain=~.1f  with stacktrace caller-check=~.1f  (ratio ~.1fx)~n", [Plain, Guard, Guard/Plain]),
    case {TailSeen, BodySeen} of
        {false, true} -> io:format("FINDING: runtime caller check is blind to tail callers~n");
        _ -> io:format("FAIL: expected tail=false body=true~n"), halt(1)
    end.
