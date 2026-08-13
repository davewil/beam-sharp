%%% PROTOTYPE 25c — exemplar 3 of 6: an event-queue consumer (AMQP 0-9-1).
%%%
%%% Throwaway. Ticket 25. This is the Erlang a beam-sharp `lib/shop/queue/`
%%% directory would lower to. Every claim in 25c-event-queue-consumer.md is
%%% produced by running this file; nothing there was reasoned about only on paper.
%%%
%%%   erlc 25c_queue_lowering.erl && erl -noshell -s 25c_queue_lowering main -s init stop
%%%
%%% AMQP 0-9-1 frame:  type:8, channel:16, size:32, payload:size, 16#CE:8
%%% Method payload:    class:16, method:16, args
%%% Basic.Deliver:     class 60, method 60
-module('25c_queue_lowering').
-export([main/0]).

-define(FRAME_END, 16#CE).

%%%===================================================================
%%% frame.bs — decoding, and the two gaps ticket 30 named
%%%===================================================================

%% Four clause heads discriminated by the VALUE of the type octet, each with a
%% payload segment whose size is a variable bound earlier in the same pattern.
%% Ticket 30's two gaps, in one head, in a second wire format.
-spec decode_frame(binary()) ->
          {ok, {method | header | body | heartbeat, integer(), binary()}, binary()}
        | {error, atom()}.
decode_frame(<<1:8, Ch:16, Size:32, Payload:Size/binary, ?FRAME_END:8, Rest/binary>>) ->
    {ok, {method, Ch, Payload}, Rest};
decode_frame(<<2:8, Ch:16, Size:32, Payload:Size/binary, ?FRAME_END:8, Rest/binary>>) ->
    {ok, {header, Ch, Payload}, Rest};
decode_frame(<<3:8, Ch:16, Size:32, Payload:Size/binary, ?FRAME_END:8, Rest/binary>>) ->
    {ok, {body, Ch, Payload}, Rest};
decode_frame(<<8:8, Ch:16, 0:32, ?FRAME_END:8, Rest/binary>>) ->
    {ok, {heartbeat, Ch, <<>>}, Rest};
%% The frame-end octet is a checked constant: a frame whose length field lies
%% lands here rather than in the clause above it.
decode_frame(<<T:8, _Ch:16, Size:32, _:Size/binary, Bad:8, _/binary>>) when Bad =/= ?FRAME_END ->
    {error, {bad_frame_end, T, Bad}};
decode_frame(<<T:8, _/binary>>) when T =/= 1, T =/= 2, T =/= 3, T =/= 8 ->
    {error, {unknown_frame_type, T}};
decode_frame(_) ->
    {error, incomplete}.

%% AMQP shortstr: a length octet then that many bytes. The bound-variable segment
%% again, nested inside a payload that was itself sized by a bound variable.
-spec shortstr(binary()) -> {binary(), binary()}.
shortstr(<<Len:8, S:Len/binary, Rest/binary>>) -> {S, Rest}.

%%%===================================================================
%%% method.bs — a 16-bit class/method pair, the escalation of 25b's opcode
%%%===================================================================

-spec decode_method(binary()) -> {ok, map()} | {error, atom()}.
decode_method(<<60:16, 60:16, Args/binary>>) -> decode_deliver(Args);
decode_method(<<60:16, 80:16, _/binary>>)    -> {error, unexpected_ack};
decode_method(<<C:16, M:16, _/binary>>)      -> {error, {unhandled_method, C, M}};
decode_method(_)                             -> {error, malformed_method}.

%% Basic.Deliver args: consumer-tag shortstr, delivery-tag longlong,
%% redelivered bit (packed LSB-first into one octet), exchange, routing-key.
-spec decode_deliver(binary()) -> {ok, map()} | {error, atom()}.
decode_deliver(Args) ->
    {Tag, R1} = shortstr(Args),
    case R1 of
        <<DTag:64, _:7, Redelivered:1, R2/binary>> ->
            {Exchange, R3} = shortstr(R2),
            {RKey, _}      = shortstr(R3),
            {ok, #{consumer_tag => Tag, delivery_tag => DTag,
                   redelivered => Redelivered =:= 1,
                   exchange => Exchange, routing_key => RKey}};
        _ ->
            {error, malformed_deliver}
    end.

%%%===================================================================
%%% consume.bs — three fallible stages, which is what 25a said `|?>` needs
%%%===================================================================

%% beam-sharp:
%%   raw |?> DecodeFrame() |?> DecodeBody() |?> ValidateAs<OrderPlaced>()
%% The valve lowers to nested cases that short-circuit on `{error, _}`.
-spec consume(binary()) -> {ok, map()} | {error, term()}.
consume(Raw) ->
    case decode_frame(Raw) of
        {error, E1} -> {error, {stage1, E1}};
        {ok, {method, _Ch, Payload}, Rest} ->
            case decode_method(Payload) of
                {error, E2} -> {error, {stage2, E2}};
                {ok, Deliver} ->
                    case body_of(Rest) of
                        {error, E3} -> {error, {stage3, E3}};
                        {ok, Body} ->
                            case validate_order(Body) of
                                {error, E4}  -> {error, {stage4, E4}};
                                {ok, Order}  -> {ok, Deliver#{order => Order}}
                            end
                    end
            end;
        {ok, {Other, _, _}, _} -> {error, {stage1, {want_method, Other}}}
    end.

%% Skip the content header, take the body frame.
body_of(Bin) ->
    case decode_frame(Bin) of
        {ok, {header, _, _}, Rest} ->
            case decode_frame(Rest) of
                {ok, {body, _, Body}, _} -> {ok, Body};
                {ok, {O, _, _}, _}       -> {error, {want_body, O}};
                {error, E}               -> {error, E}
            end;
        {ok, {O, _, _}, _} -> {error, {want_header, O}};
        {error, E}         -> {error, E}
    end.

%% ValidateAs<OrderPlaced> — ticket 18's boundary guard over a foreign payload.
%% The queue body is bytes chosen by whoever published; ticket 21 says you cannot
%% rule out a foreign sender, so every field is checked, not pattern-bound.
-spec validate_order(binary()) -> {ok, map()} | {error, term()}.
validate_order(Body) ->
    case parse_pairs(Body) of
        {error, E} -> {error, E};
        {ok, M} ->
            Id  = maps:get(<<"id">>, M, undefined),
            Qty = maps:get(<<"qty">>, M, undefined),
            case {Id, Qty} of
                {undefined, _} -> {error, {missing_field, id}};
                {_, undefined} -> {error, {missing_field, qty}};
                {_, _} ->
                    case to_int(Qty) of
                        error -> {error, {not_an_integer, qty}};
                        {ok, N} when N > 0 -> {ok, #{id => Id, qty => N}};
                        {ok, N}            -> {error, {qty_not_positive, N}}
                    end
            end
    end.

%% A deliberately tiny `k=v;k=v` payload parser: the exemplar is about the queue,
%% not about JSON, and ticket 25a already covered JSON in and out.
parse_pairs(Body) ->
    try
        Pairs = [begin
                     [K, V] = binary:split(P, <<"=">>),
                     {K, V}
                 end || P <- binary:split(Body, <<";">>, [global]), P =/= <<>>],
        {ok, maps:from_list(Pairs)}
    catch _:_ -> {error, malformed_body}
    end.

to_int(B) ->
    try {ok, binary_to_integer(B)} catch _:_ -> error end.

%%%===================================================================
%%% disposition.bs — ticket 17 job 1: does a long ladder actually occur?
%%%===================================================================

%% ack | requeue | dead-letter, from four unrelated conditions. Ticket 17 §6 made
%% `switch` the only branching construct with a TUPLE SUBJECT for the compound
%% case; this is that shape at width 4, lowered as a case over a tuple.
-spec disposition({ok, map()} | {error, term()}, boolean(), non_neg_integer()) ->
          ack | requeue | dead_letter.
disposition(Outcome, Redelivered, DeliveryCount) ->
    Permanent = is_permanent(Outcome),
    Ok        = element(1, Outcome) =:= ok,
    case {Ok, Permanent, Redelivered, DeliveryCount >= 5} of
        {true,  _,     _,     _}     -> ack;
        {false, true,  _,     _}     -> dead_letter;
        {false, false, _,     true}  -> dead_letter;
        {false, false, false, false} -> requeue;
        {false, false, true,  false} -> requeue
    end.

%% A validation failure is the publisher's fault and will fail identically
%% forever; a frame-level failure may be a torn read. Ticket 15's distinction
%% between a declared failure channel and a transient one, at the disposition.
is_permanent({error, {stage4, _}}) -> true;
is_permanent({error, {stage2, _}}) -> true;
is_permanent(_)                    -> false.

%%%===================================================================
%%% encode.bs — ticket 17 job 2, and why the pipe cannot build a frame
%%%===================================================================

%% Basic.Ack is class 60 method 80: delivery-tag longlong, multiple bit.
%% The header carries the payload's SIZE, so it cannot be written until the
%% payload exists. Left-to-right accumulation is impossible by construction.
-spec encode_ack(integer(), boolean()) -> binary().
encode_ack(DeliveryTag, Multiple) ->
    M = case Multiple of true -> 1; false -> 0 end,
    Payload = <<60:16, 80:16, DeliveryTag:64, 0:7, M:1>>,   % step 1: build the inside
    Size = byte_size(Payload),                              % step 2: measure it
    <<1:8, 1:16, Size:32, Payload/binary, ?FRAME_END:8>>.    % step 3: wrap it

%% The same shape written as an accumulation, to show what it costs.
-spec encode_ack_piped(integer(), boolean()) -> binary().
encode_ack_piped(DeliveryTag, Multiple) ->
    M = case Multiple of true -> 1; false -> 0 end,
    Payload = lists:foldl(fun(Seg, Acc) -> <<Acc/bitstring, Seg/bitstring>> end,
                          <<>>,
                          [<<60:16>>, <<80:16>>, <<DeliveryTag:64>>, <<0:7>>, <<M:1>>]),
    frame(1, 1, Payload).

frame(Type, Ch, Payload) ->
    <<Type:8, Ch:16, (byte_size(Payload)):32, Payload/binary, ?FRAME_END:8>>.

%%%===================================================================
%%% handle_info.bs — ticket 14's process model, with prefetch back-pressure
%%%===================================================================

consumer(Parent, Prefetch) ->
    consumer_loop(Parent, Prefetch, 0, []).

consumer_loop(Parent, Prefetch, InFlight, Acc) ->
    receive
        {deliver, Raw} when InFlight >= Prefetch ->
            %% Back-pressure: at the prefetch ceiling the consumer stops taking
            %% work. The message is NOT dropped — it stays in the mailbox,
            %% because a `receive` is a filter (ticket 14 §5).
            self() ! {blocked_marker, Raw},
            consumer_loop(Parent, Prefetch, InFlight, Acc);
        {deliver, Raw} ->
            Result = consume(Raw),
            D = disposition(Result, false, 1),
            consumer_loop(Parent, Prefetch, InFlight + 1, [D | Acc]);
        {settle, N} ->
            consumer_loop(Parent, Prefetch, max(0, InFlight - N), Acc);
        report ->
            Parent ! {report, lists:reverse(Acc), InFlight, mailbox_len()},
            ok
    after 200 ->
        Parent ! {report, lists:reverse(Acc), InFlight, mailbox_len()},
        ok
    end.

mailbox_len() ->
    {message_queue_len, N} = process_info(self(), message_queue_len),
    N.

%%%===================================================================
%%% main
%%%===================================================================

sample_deliver_frames(Qty) ->
    CTag  = <<"ctag-1">>,
    Ex    = <<"orders">>,
    RKey  = <<"order.placed">>,
    Args  = <<(byte_size(CTag)):8, CTag/binary,
              42:64, 0:7, 0:1,
              (byte_size(Ex)):8, Ex/binary,
              (byte_size(RKey)):8, RKey/binary>>,
    Method = frame(1, 1, <<60:16, 60:16, Args/binary>>),
    Header = frame(2, 1, <<60:16, 0:16, 32:64, 0:16>>),
    Body   = frame(3, 1, <<"id=A-1;qty=", (integer_to_binary(Qty))/binary>>),
    <<Method/binary, Header/binary, Body/binary>>.

main() ->
    p("== ticket 30 gap 1: a segment sized by a bound variable =="),
    Raw = sample_deliver_frames(3),
    p("decode_frame/1     -> ~p", [element(2, decode_frame(Raw))]),
    p("shortstr/1         -> ~p", [shortstr(<<3:8, "abc", "tail">>)]),

    p(""),
    p("== ticket 30 gap 2: a union discriminated by a value INSIDE the binary =="),
    [p("  type octet ~p    -> ~p", [T, tag_of(decode_frame(frame(T, 1, <<>>)))])
     || T <- [1, 2, 3, 8, 4]],
    p("  heartbeat        -> ~p", [decode_frame(<<8:8, 1:16, 0:32, ?FRAME_END:8>>)]),

    p(""),
    p("== the frame-end octet catches a lying length field =="),
    Lie = <<1:8, 1:16, 99:32, 0:(99*8), 16#FF:8>>,
    p("  bad frame end    -> ~p", [decode_frame(Lie)]),

    p(""),
    p("== 25a's question: does `|?>` earn its place at three stages? =="),
    p("  all good         -> ~p", [consume(Raw)]),
    p("  stage 1 (frame)  -> ~p", [consume(<<9:8, 1:16, 0:32, ?FRAME_END:8>>)]),
    p("  stage 2 (method) -> ~p", [consume(frame(1, 1, <<60:16, 21:16>>))]),
    p("  stage 4 (payload)-> ~p", [consume(sample_deliver_frames(0))]),
    p("  stage 4 (nonint) -> ~p", [consume(bad_qty_frames())]),

    p(""),
    p("== ticket 17 job 1: the disposition ladder, width 4 =="),
    [p("  ~-34s -> ~p", [fmt(O, R, C), disposition(O, R, C)])
     || {O, R, C} <- [{{ok, #{}}, false, 1},
                      {{error, {stage4, bad}}, false, 1},
                      {{error, {stage1, incomplete}}, true, 2},
                      {{error, {stage1, incomplete}}, true, 7}]],

    p(""),
    p("== ticket 17 job 2: building a length-prefixed frame =="),
    A1 = encode_ack(42, false),
    A2 = encode_ack_piped(42, false),
    p("  encode_ack       -> ~p", [A1]),
    p("  identical piped  -> ~p", [A1 =:= A2]),
    p("  one-bit chunk    -> ~p", [catch frame(1, 1, <<1:1>>)]),

    p(""),
    p("== ticket 14: prefetch back-pressure, and what the mailbox does =="),
    Self = self(),
    Pid = spawn(fun() -> consumer(Self, 2) end),
    [Pid ! {deliver, Raw} || _ <- lists:seq(1, 4)],
    Pid ! report,
    receive
        {report, Ds, InFlight, MboxLen} ->
            p("  dispositions     -> ~p", [Ds]),
            p("  in flight        -> ~p (prefetch 2)", [InFlight]),
            p("  mailbox at exit  -> ~p", [MboxLen])
    after 2000 -> p("  TIMEOUT")
    end,
    ok.

bad_qty_frames() ->
    CTag = <<"c">>, Ex = <<"e">>, RKey = <<"r">>,
    Args = <<(byte_size(CTag)):8, CTag/binary, 7:64, 0:7, 0:1,
             (byte_size(Ex)):8, Ex/binary, (byte_size(RKey)):8, RKey/binary>>,
    <<(frame(1, 1, <<60:16, 60:16, Args/binary>>))/binary,
      (frame(2, 1, <<60:16, 0:16, 8:64, 0:16>>))/binary,
      (frame(3, 1, <<"id=A-2;qty=lots">>))/binary>>.

tag_of({ok, {T, _, _}, _}) -> T;
tag_of({error, E})         -> E.

fmt(O, R, C) ->
    lists:flatten(io_lib:format("~p r=~p n=~p", [element(1, O), R, C])).

p(S)       -> io:format("~s~n", [S]).
p(F, A)    -> io:format(F ++ "~n", A).
