%%% 20b — Is the binary type grammar admissible at ticket 18 §2's boundary?
%%%
%%% Ticket 18 §2: a foreign declaration may promise only what one BEAM guard
%%% decides in O(1). Ticket 20 inherited the open question "what may a foreign
%%% declaration say about a binary?" — `binary` and nothing more, or structure?
%%%
%%% The answer is the whole grammar, because <<_:M, _:_*N>> reduces to two
%%% arithmetic tests on the term header:
%%%
%%%     base M   ->  byte_size(B) =:= M div 8   (exact)  or  >= M div 8 (with unit)
%%%     unit N   ->  bit_size(B) rem N =:= 0
%%%
%%% Both byte_size/1 and bit_size/1 are guard BIFs, and both are O(1) — the size
%%% lives in the term header, not in the content.
%%%
%%% Run: erlc +debug_info -o . 20b_binary_boundary_guards.erl
%%%      erl -noshell -pa . -eval "'20b_binary_boundary_guards':run(),halt()."
%%%
%%% Measured on OTP 28.5, 2026-08-13.

-module('20b_binary_boundary_guards').
-export([run/0, m32/1, hdr/1, unit3/1, join/1]).

%% --- <<_:32>> : an exact size ----------------------------------------------
m32(B)   when is_binary(B),    byte_size(B) =:= 4      -> exactly_32_bits;
m32(_)                                                 -> no.

%% --- <<_:32,_:_*8>> : a 4-byte header plus a whole-byte payload ------------
hdr(B)   when is_binary(B),    byte_size(B) >= 4       -> header_plus_payload;
hdr(_)                                                 -> no.

%% --- <<_:_*3>> : a repeating unit is a modulus, not a traversal ------------
unit3(B) when is_bitstring(B), bit_size(B) rem 3 =:= 0 -> unit_3;
unit3(_)                                               -> no.

%% --- Ticket 17 §3 handed ticket 20 a question: is the fixpoint widening
%%     avoidable? 17 measured `bitstring()` where lists:foldl gave `binary()`,
%%     and asked whether a declared binary type in the surface language would
%%     let the compiler emit `binary()`.
%%
%%     It would, and the widening was never a codegen artefact: 17's probe
%%     simply declared no spec, so Dialyzer inferred one. Ticket 13 has
%%     beam-sharp emitting a -spec for every function whose type is known, and
%%     a declared spec lands in the abstract chunk verbatim. See spec/0 below.
-spec join([integer()]) -> binary().
join([])      -> <<>>;
join([H | T]) -> <<(integer_to_binary(H))/binary, (join(T))/binary>>.

run() ->
    io:format("=== the grammar as O(1) guards ===~n"),
    io:format("m32   <<1,2,3,4>>     : ~p~n", [m32(<<1,2,3,4>>)]),      % exactly_32_bits
    io:format("m32   <<1,2,3,4,5>>   : ~p~n", [m32(<<1,2,3,4,5>>)]),    % no
    io:format("hdr   <<1,2,3,4,5,6>> : ~p~n", [hdr(<<1,2,3,4,5,6>>)]),  % header_plus_payload
    io:format("hdr   <<1,2>>         : ~p~n", [hdr(<<1,2>>)]),          % no
    io:format("unit3 <<0:9>>         : ~p~n", [unit3(<<0:9>>)]),        % unit_3
    io:format("unit3 <<0:10>>        : ~p~n", [unit3(<<0:10>>)]),       % no

    io:format("~n=== byte_size/1 is O(1): the size is in the header ===~n"),
    Small = binary:copy(<<0>>, 8),
    Big   = binary:copy(<<0>>, 8 * 1024 * 1024),
    io:format("1M calls on 8 B   : ~p us~n", [time_it(fun() -> byte_size(Small) end)]),
    io:format("1M calls on 8 MiB : ~p us~n", [time_it(fun() -> byte_size(Big) end)]),
    %% measured 2833 us vs 2633 us — indistinguishable, and the larger one was
    %% marginally faster, which is noise.

    io:format("~n=== the declared spec is what lands in the .beam ===~n"),
    io:format("join([1,2,3]) = ~p~n", [join([1,2,3])]),
    spec().

%% Read our own abstract chunk back and print the spec that was emitted.
spec() ->
    case beam_lib:chunks(code:which(?MODULE), [abstract_code]) of
        {ok, {_, [{abstract_code, {_, Forms}}]}} ->
            [io:format("emitted: ~s", [erl_pp:attribute(F)])
             || F = {attribute, _, spec, {{join, 1}, _}} <- Forms];
            %% => -spec join([integer()]) -> binary().
            %%    NOT bitstring(), which is what success typing infers for the
            %%    same body when nothing is declared (ticket 17 §3).
        _ ->
            io:format("(compile with +debug_info to see the emitted spec)~n")
    end.

time_it(F) ->
    {T, _} = timer:tc(fun() -> loop(1000000, F) end),
    T.
loop(0, _) -> ok;
loop(N, F) -> F(), loop(N - 1, F).
