%%% bs_capture — stdout and stderr, caught in-process, in the order they were
%%% written.
%%%
%%% ENG-314. `bsc --batch` runs many invocations in one VM and owes each of
%%% them the three things a gate reads from a subprocess: what it wrote to
%%% stdout, what it wrote to stderr, and the two interleaved as `2>&1` would
%%% have delivered them. `bsc` also compiles the emitted `.abstr` in-process
%%% now, and the compiler's warning text has to be read back the way `erlc`'s
%%% output was read from a port.
%%%
%%% HOW A WRITE REACHES HERE. Erlang IO is a protocol: `io:format/2` sends an
%%% `io_request` to the caller's group leader and waits for the reply, and
%%% `io:format(standard_error, …)` sends the same request to whatever process
%%% is registered under that name. So a capture is a process that speaks the
%%% protocol — and to tell the two streams apart it is THREE processes: two
%%% thin faces, one installed as the group leader and one registered as
%%% `standard_error`, each tagging what it receives with its stream and
%%% forwarding to a single server that keeps the buffers and answers the
%%% caller. One server, not two, is what makes the merged stream's order a
%%% guarantee rather than an observation: every write waits for its reply, so
%%% the next write cannot be sent until the previous one has been buffered.
%%%
%%% THE BYTES ARE THE DEVICE'S BYTES. A real device encodes the characters it
%%% is handed according to its own `encoding` option — measured on OTP 28 with
%%% both streams redirected to files, that is `unicode` for both, so a `~s`
%%% over the raw bytes of a UTF-8 name double-encodes exactly as it does when
%%% `bsc` runs alone. The encodings are read from the real devices when the
%%% capture starts and applied here, rather than assumed.
-module(bs_capture).

-export([start/0, stop/1, run/2]).

-record(capture, {server, stdout, stderr, real_stderr}).

%% Install a capture: the calling process's group leader and the registered
%% `standard_error` both now write here. Returns the handle `stop/1` needs.
start() ->
    Encodings = {device_encoding(standard_io), device_encoding(standard_error)},
    Server = spawn_link(fun() -> server(Encodings, [], [], []) end),
    Out = spawn_link(fun() -> face(stdout, Server) end),
    Err = spawn_link(fun() -> face(stderr, Server) end),
    Real = whereis(standard_error),
    unregister(standard_error),
    register(standard_error, Err),
    #capture{server = Server, stdout = Out, stderr = Err, real_stderr = Real}.

%% Restore the real `standard_error` and hand back the three streams as
%% binaries: `{Stdout, Stderr, Merged}`.
stop(#capture{server = Server, stdout = Out, stderr = Err, real_stderr = Real}) ->
    unregister(standard_error),
    register(standard_error, Real),
    Server ! {collect, self()},
    Result = receive {collected, Server, R} -> R end,
    unlink(Out), unlink(Err), unlink(Server),
    exit(Out, kill), exit(Err, kill), exit(Server, kill),
    Result.

%% Run `Fun` in a fresh process whose group leader is the capture's stdout
%% face, and return `{Outcome, {Stdout, Stderr, Merged}}` where Outcome is
%% `{ok, Value}` or `{crashed, Class, Reason}`. Everything the fun writes to
%% either stream is caught; the caller's own streams are untouched.
run(Fun, Timeout) ->
    Capture = start(),
    Parent = self(),
    {Worker, Ref} =
        spawn_monitor(fun() ->
                              group_leader(Capture#capture.stdout, self()),
                              Parent ! {result, self(), try {ok, Fun()}
                                                        catch C:R -> {crashed, C, R}
                                                        end}
                      end),
    Outcome = receive
                  {result, Worker, R} ->
                      receive {'DOWN', Ref, process, Worker, _} -> ok end,
                      R;
                  {'DOWN', Ref, process, Worker, Reason} ->
                      {crashed, exit, Reason}
              after Timeout ->
                      exit(Worker, kill),
                      receive {'DOWN', Ref, process, Worker, _} -> ok end,
                      {crashed, exit, timeout}
              end,
    {Outcome, stop(Capture)}.

%%% ---------------------------------------------------------------------------
%%% The faces and the server
%%% ---------------------------------------------------------------------------

face(Stream, Server) ->
    receive
        {io_request, From, ReplyAs, Request} ->
            Server ! {io_request, Stream, From, ReplyAs, Request},
            face(Stream, Server)
    end.

server({OutEnc, ErrEnc} = Encs, Out, Err, Merged) ->
    receive
        {io_request, Stream, From, ReplyAs, Request} ->
            DevEnc = case Stream of stdout -> OutEnc; stderr -> ErrEnc end,
            {Reply, Bin} = answer(Request, DevEnc, <<>>),
            From ! {io_reply, ReplyAs, Reply},
            case Stream of
                stdout -> server(Encs, [Bin | Out], Err, [Bin | Merged]);
                stderr -> server(Encs, Out, [Bin | Err], [Bin | Merged])
            end;
        {collect, Who} ->
            Who ! {collected, self(),
                   {iolist_to_binary(lists:reverse(Out)),
                    iolist_to_binary(lists:reverse(Err)),
                    iolist_to_binary(lists:reverse(Merged))}}
    end.

%% The requests a writer sends. `put_chars` in both of its forms is what
%% `io:format` and `io:put_chars` produce; `requests` batches several; the
%% option requests are answered so a caller that asks is not hung. Anything
%% that READS is answered `eof` — a batch entry has no stdin, which is also why
%% the REPL is refused in one.
answer({put_chars, Enc, Chars}, DevEnc, Acc) ->
    put_chars(Chars, Enc, DevEnc, Acc);
answer({put_chars, Enc, M, F, A}, DevEnc, Acc) ->
    try apply(M, F, A) of
        Chars -> put_chars(Chars, Enc, DevEnc, Acc)
    catch
        _:_ -> {{error, F}, Acc}
    end;
answer({requests, Reqs}, DevEnc, Acc) ->
    lists:foldl(fun(R, {_, A}) -> answer(R, DevEnc, A) end, {ok, Acc}, Reqs);
answer({setopts, _}, _DevEnc, Acc)       -> {ok, Acc};
answer(getopts, DevEnc, Acc)              -> {[{encoding, DevEnc}], Acc};
answer({get_geometry, _}, _DevEnc, Acc)   -> {{error, enotsup}, Acc};
answer({get_chars, _, _, _}, _DevEnc, Acc)      -> {eof, Acc};
answer({get_line, _, _}, _DevEnc, Acc)          -> {eof, Acc};
answer({get_until, _, _, _, _, _}, _DevEnc, Acc) -> {eof, Acc};
answer(_Other, _DevEnc, Acc)              -> {{error, request}, Acc}.

put_chars(Chars, Enc, DevEnc, Acc) ->
    case unicode:characters_to_binary(Chars, Enc, DevEnc) of
        Bin when is_binary(Bin) -> {ok, <<Acc/binary, Bin/binary>>};
        _ -> {{error, {no_translation, Enc, DevEnc}}, Acc}
    end.

device_encoding(Device) ->
    case io:getopts(Device) of
        Opts when is_list(Opts) -> proplists:get_value(encoding, Opts, latin1);
        _                        -> latin1
    end.
