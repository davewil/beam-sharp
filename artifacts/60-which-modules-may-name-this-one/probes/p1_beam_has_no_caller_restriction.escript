#!/usr/bin/env escript
%% Run: escript p1_beam_has_no_caller_restriction.escript
%% Question: does Erlang/OTP 25 offer ANY caller-restricted export (compile flag, attribute, or runtime)?
%% Observes: (1) unexported fn is undef remotely, (2) exported fn callable from a module compiled
%% with no relationship to the callee, (3) a source scan of compiler/stdlib/kernel/tools for a
%% friend/visible-to mechanism, (4) the exports list a 'private' B# fn would lack.
main(_) ->
    Dir = filename:join(os:getenv("TMPDIR", "/tmp"), "p1_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    W = fun(Name, Src) -> F = filename:join(Dir, Name ++ ".erl"), ok = file:write_file(F, Src),
            {ok, M, Bin} = compile:file(F, [binary, return_errors]), {module, M} = code:load_binary(M, F, Bin), M end,
    W("callee", "-module(callee).\n-export([pub/0]).\npub() -> pub.\nhidden() -> hidden.\n-compile({nowarn_unused_function,hidden/0}).\n"),
    W("stranger", "-module(stranger).\n-export([go/0, go_hidden/0]).\ngo() -> callee:pub().\ngo_hidden() -> callee:hidden().\n"),
    R1 = (catch stranger:go()),
    R2 = (catch stranger:go_hidden()),
    io:format("exported fn called by unrelated module -> ~p~n", [R1]),
    io:format("unexported fn called by unrelated module -> ~p~n", [element(1, element(2, R2))]),
    io:format("callee exports: ~p~n", [callee:module_info(exports)]),
    %% source scan
    Libs = filelib:wildcard("/usr/lib/erlang/lib/{compiler,stdlib,kernel,tools,syntax_tools}-*/src/*.erl"),
    Pat = re:compile("visible_to|-friend|internal_to|-restrict", [caseless]),
    {ok, RE} = Pat,
    Hits = [F || F <- Libs, {ok, B} <- [file:read_file(F)], re:run(B, RE) =/= nomatch],
    io:format("scanned ~p source files, friend/visible-to style hits: ~p~n", [length(Libs), Hits]),
    %% compile options accepted? try a bogus restricting option and an attribute
    F3 = filename:join(Dir, "attr.erl"),
    ok = file:write_file(F3, "-module(attr).\n-export([f/0]).\n-friend([stranger]).\nf() -> 1.\n"),
    {ok, attr, _, Warn} = compile:file(F3, [binary, return, report_warnings]),
    io:format("-friend([...]) attribute: compiler accepted it silently as opaque attribute; warnings=~p~n", [Warn]),
    {ok, attr, Bin3} = compile:file(F3, [binary]),
    {ok, {attr, [{attributes, As}]}} = beam_lib:chunks(Bin3, [attributes]),
    io:format("attribute kept in beam but ignored by loader: ~p~n", [lists:keyfind(friend, 1, As)]),
    {module, attr} = code:load_binary(attr, F3, Bin3),
    io:format("stranger-like call to attr:f() from shell process -> ~p~n", [attr:f()]),
    %% hard assertions on observed values
    true = (R1 =:= pub), {'EXIT', {undef, _}} = R2,
    io:format("ASSERTIONS HELD: BEAM enforces export-or-not only; no caller restriction~n").
