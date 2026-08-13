%% PROTOTYPE 25b — throwaway. The Erlang that the WebSocket exemplar lowers to.
%%
%% Ticket 25's second requirement: a lowering that COMPILES AND RUNS. Written to
%% falsify claims the beam-sharp source can only assert:
%%
%%   - RFC 6455 frame headers as a union of binary types    -> ticket 20's <<_:M,_:_*N>>
%%   - frame dispatch as multi-clause heads on a binary     -> ticket 08
%%   - a long-lived process naming Down/Exit/Timeout        -> ticket 14 §6
%%   - output built by ACCUMULATION under the pipe          -> ticket 17 §3 (job 2)
%%   - closed vs open residual on the opcode                -> ticket 12 §2
%%
%% Run: erlc 25b_websocket_lowering.erl && erl -noshell -s '25b_websocket_lowering' demo -s init stop

-module('25b_websocket_lowering').
-export([decode/1, encode/2, fragments/1, conn_loop/1, demo/0]).

%% ---------------------------------------------------------------------------
%% 1. Frame decoding — the part beam-sharp wants as multi-clause heads
%% ---------------------------------------------------------------------------
%%
%% RFC 6455 frame header, first two bytes:
%%   FIN:1, RSV:3, Opcode:4, Mask:1, Len:7
%% then 0/2/8 bytes of extended length, then 0/4 bytes of masking key.
%%
%% THE FINDING THIS FILE EXISTS FOR: the payload length is not a *type*
%% distinction, it is a VALUE distinction that selects the header's shape.
%% 126 and 127 are sentinels. So the three header shapes are NOT three members
%% of a binary union the checker can discriminate by size — they are selected by
%% an integer field's value, which is a guard on a bound variable, not a shape.

decode(<<_Fin:1, _Rsv:3, Op:4, 1:1, 126:7, Len:16, Mask:4/binary,
         Payload:Len/binary, Rest/binary>>) ->
    {frame, opcode(Op), unmask(Payload, Mask), Rest};

decode(<<_Fin:1, _Rsv:3, Op:4, 1:1, 127:7, Len:64, Mask:4/binary,
         Payload:Len/binary, Rest/binary>>) ->
    {frame, opcode(Op), unmask(Payload, Mask), Rest};

decode(<<_Fin:1, _Rsv:3, Op:4, 1:1, Len:7, Mask:4/binary,
         Payload:Len/binary, Rest/binary>>) when Len < 126 ->
    {frame, opcode(Op), unmask(Payload, Mask), Rest};

%% An unmasked client frame is a protocol violation (RFC 6455 §5.1), NOT a
%% short read. Distinguishing it from "need more bytes" needs its own clause,
%% and it has to come before the catch-all.
decode(<<_Fin:1, _Rsv:3, _Op:4, 0:1, _/bitstring>>) ->
    {error, unmasked_client_frame};

%% The boundary clause. The residual here is OPEN — the remainder of a socket
%% read is any bitstring at all — so ticket 12 permits `_`.
decode(_Partial) ->
    {error, incomplete}.

%% Opcode: a CLOSED residual. 16 values, all named by the RFC. Ticket 12 says a
%% catch-all here is an ERROR, so every case is named. Counted in the writeup.
opcode(0)  -> continuation;
opcode(1)  -> text;
opcode(2)  -> binary;
opcode(3)  -> reserved_3;
opcode(4)  -> reserved_4;
opcode(5)  -> reserved_5;
opcode(6)  -> reserved_6;
opcode(7)  -> reserved_7;
opcode(8)  -> close;
opcode(9)  -> ping;
opcode(10) -> pong;
opcode(11) -> reserved_b;
opcode(12) -> reserved_c;
opcode(13) -> reserved_d;
opcode(14) -> reserved_e;
opcode(15) -> reserved_f.

op_code(continuation) -> 0;
op_code(text)         -> 1;
op_code(binary)       -> 2;
op_code(close)        -> 8;
op_code(ping)         -> 9;
op_code(pong)         -> 10.

%% Unmasking: XOR the payload with a 4-byte rotating key. This is the loop that
%% ticket 20 says is O(n) and therefore NOT a guard refinement — you cannot
%% decide "this is a valid unmasked frame" in O(1).
unmask(Payload, Mask) ->
    unmask(Payload, Mask, 0, <<>>).

unmask(<<>>, _Mask, _I, Acc) ->
    Acc;
unmask(<<B:8, Rest/binary>>, Mask, I, Acc) ->
    K = binary:at(Mask, I rem 4),
    unmask(Rest, Mask, I + 1, <<Acc/binary, (B bxor K):8>>).

%% ---------------------------------------------------------------------------
%% 2. Frame encoding — ticket 17 job 2: accumulation under the pipe
%% ---------------------------------------------------------------------------
%%
%% beam-sharp writes this as a pipe:
%%     Op |> Frame.Header(size) |> Frame.Payload(body) |> Frame.Finish()
%% Each stage APPENDS to a binary accumulator. Ticket 17 §3 measured that fold's
%% inlined lowering widens such an accumulator to bitstring() at the fixpoint.
%% Here the same shape is written by hand so the widening can be observed.

encode(Op, Payload) when is_binary(Payload) ->
    Len = byte_size(Payload),
    Header = header(op_code(Op), Len),
    <<Header/binary, Payload/binary>>.

header(Op, Len) when Len < 126 ->
    <<1:1, 0:3, Op:4, 0:1, Len:7>>;
header(Op, Len) when Len < 65536 ->
    <<1:1, 0:3, Op:4, 0:1, 126:7, Len:16>>;
header(Op, Len) ->
    <<1:1, 0:3, Op:4, 0:1, 127:7, Len:64>>.

%% The accumulation shape ticket 17 §3 is about, written as a fold. The
%% accumulator starts as <<>> and each step appends — the compiler cannot prove
%% the result stays byte-aligned without knowing every element is a binary.
fragments(Chunks) ->
    lists:foldl(fun(C, Acc) -> <<Acc/binary, C/binary>> end, <<>>, Chunks).

%% ---------------------------------------------------------------------------
%% 3. The connection process — ticket 14's handle_info, named message types
%% ---------------------------------------------------------------------------
%%
%% Not a gen_server: ticket 14 §5 says `receive` is a FILTER and exists in the
%% surface, so an exemplar may show a raw process. Unmatched messages STAY IN
%% THE MAILBOX — demonstrated below.

conn_loop(State) ->
    receive
        %% ticket 14 §6: the prelude knows these shapes, so beam-sharp NAMES
        %% them (Down / Exit / Timeout) rather than spelling the tuples.
        {'DOWN', _Ref, process, Pid, Reason} ->
            {down, Pid, Reason};
        {'EXIT', Pid, Reason} ->
            {exit, Pid, Reason};
        {tcp, _Sock, Data} ->
            case decode(Data) of
                {frame, close, _, _}    -> {closed, State};
                {frame, ping, P, _}     -> {pong_sent, encode(pong, P)};
                {frame, Op, P, _}       -> conn_loop([{Op, P} | State]);
                {error, R}              -> {protocol_error, R}
            end
    after 50 ->
        {timeout, State}
    end.

%% ---------------------------------------------------------------------------
%% 4. Demo — every claim above, executed
%% ---------------------------------------------------------------------------

demo() ->
    io:format("~n== 25b: WebSocket frame codec ==~n~n"),

    %% A masked client text frame carrying "hi"
    Mask = <<1, 2, 3, 4>>,
    Masked = unmask(<<"hi">>, Mask),          %% XOR is its own inverse
    Small = <<1:1, 0:3, 1:4, 1:1, 2:7, Mask/binary, Masked/binary>>,
    io:format("small masked text  -> ~p~n", [decode(Small)]),

    %% A 126-byte payload forces the 16-bit extended length header
    Body = binary:copy(<<"x">>, 200),
    M2 = unmask(Body, Mask),
    Ext = <<1:1, 0:3, 2:4, 1:1, 126:7, 200:16, Mask/binary, M2/binary>>,
    {frame, Op2, P2, _} = decode(Ext),
    io:format("200-byte binary    -> op=~p size=~p~n", [Op2, byte_size(P2)]),

    %% Protocol violation vs short read — two different errors
    io:format("unmasked frame     -> ~p~n",
              [decode(<<1:1, 0:3, 1:4, 0:1, 2:7, "hi">>)]),
    io:format("truncated frame    -> ~p~n", [decode(<<1:1, 0:3, 1:4, 1:1, 9:7>>)]),

    %% Round trip
    Enc = encode(text, <<"round trip">>),
    io:format("encode text        -> ~p~n", [Enc]),
    io:format("header is 2 bytes  -> ~p~n", [byte_size(Enc) - 10]),

    %% Accumulation, ticket 17 job 2
    io:format("fragments concat   -> ~p~n", [fragments([<<"a">>, <<"bc">>, <<"def">>])]),

    %% THE BITSTRING FINDING: a single non-byte-aligned chunk poisons the
    %% accumulator, and nothing in the fold's shape prevents it.
    Bad = (catch fragments([<<"a">>, <<1:1>>])),
    io:format("fragments w/ 1 bit -> ~p~n", [Bad]),

    %% The mailbox is a filter: send an unmatched message first, then a real one
    Self = self(),
    P = spawn(fun() -> Self ! {result, conn_loop([])} end),
    P ! {not_my_message, ignored},
    P ! {tcp, sock, Small},
    receive {result, R} -> io:format("conn_loop          -> ~p~n", [R])
    after 1000 -> io:format("conn_loop          -> TIMEOUT~n") end,

    %% Timeout path
    P3 = spawn(fun() -> Self ! {result3, conn_loop(state0)} end),
    receive {result3, R3} -> io:format("conn_loop timeout  -> ~p~n", [R3])
    after 1000 -> io:format("conn_loop timeout  -> TIMEOUT~n") end,

    ok.
