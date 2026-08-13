%%% 20a — What the BEAM's own type machinery does with binary types.
%%%
%%% Ticket 20 asks whether binaries are untheorised. They are not *ungrammared*:
%%% Erlang ships <<_:M, _:_*N>> and erl_types reasons over it. What it does not
%%% ship is an algebra a pessimistic checker can use.
%%%
%%% Run: erlc -o . 20a_binary_type_algebra.erl
%%%      erl -noshell -pa . -eval "'20a_binary_type_algebra':run(),halt()."
%%%
%%% Measured on OTP 28.5, 2026-08-13. Results are in the comments beside each line.

-module('20a_binary_type_algebra').
-export([run/0]).

run() ->
    grammar(),
    subtyping(),
    union(),
    intersection(),
    subtraction(),
    residual(),
    subsumption_vs_overlap(),
    ok.

%% ---------------------------------------------------------------------------
%% 1. The grammar exists and round-trips.
%% ---------------------------------------------------------------------------
grammar() ->
    io:format("~n=== 1. grammar ===~n"),
    show("<<_:32>>       ", erl_types:t_bitstr(0, 32)),   % <<_:32>>
    show("<<_:64>>       ", erl_types:t_bitstr(0, 64)),   % <<_:64>>
    show("<<_:_*8>>      ", erl_types:t_bitstr(8, 0)),    % binary()
    show("<<_:_*1>>      ", erl_types:t_bitstr(1, 0)),    % bitstring()
    show("<<_:32,_:_*8>> ", erl_types:t_bitstr(8, 32)).   % <<_:32,_:_*8>>

%% ---------------------------------------------------------------------------
%% 2. Subtyping is correct.
%% ---------------------------------------------------------------------------
subtyping() ->
    io:format("~n=== 2. subtyping ===~n"),
    sub("<<_:32>> <: binary()      ", erl_types:t_bitstr(0,32), erl_types:t_bitstr(8,0)),  % true
    sub("<<_:32>> <: bitstring()   ", erl_types:t_bitstr(0,32), erl_types:t_bitstr(1,0)),  % true
    sub("<<_:64>> <: <<_:32>>      ", erl_types:t_bitstr(0,64), erl_types:t_bitstr(0,32)), % false
    sub("<<_:32,_:_*8>> <: binary()", erl_types:t_bitstr(8,32), erl_types:t_bitstr(8,0)).  % true

%% ---------------------------------------------------------------------------
%% 3. UNION IS LOSSY. This is the whole finding.
%%
%%    t_sup collapses two same-constructor binary types into an arithmetic
%%    progression. <<_:32>> | <<_:64>> becomes 32, 64, 96, 128, ... — a type
%%    admitting a 96-bit value nobody declared.
%%
%%    Note what does NOT collapse: <<_:32>> | integer() stays exact, because
%%    different constructors never merge. The lossiness is same-constructor
%%    only, so it is a representation choice, not a property of the domain.
%% ---------------------------------------------------------------------------
union() ->
    io:format("~n=== 3. union (t_sup) — LOSSY ===~n"),
    show("<<_:32>> | <<_:64>>", erl_types:t_sup(erl_types:t_bitstr(0,32),
                                                erl_types:t_bitstr(0,64))),
        % => <<_:32,_:_*32>>   -- admits 96 bits
    show("<<_:32>> | <<_:40>>", erl_types:t_sup(erl_types:t_bitstr(0,32),
                                                erl_types:t_bitstr(0,40))),
        % => <<_:32,_:_*8>>    -- admits 48 bits
    show("<<_:32>> | integer", erl_types:t_sup(erl_types:t_bitstr(0,32),
                                               erl_types:t_integer())).
        % => <<_:32>> | integer()  -- EXACT: different constructors do not merge

%% ---------------------------------------------------------------------------
%% 4. Intersection is exact — and in the unit domain it is the LCM.
%% ---------------------------------------------------------------------------
intersection() ->
    io:format("~n=== 4. intersection (t_inf) — exact ===~n"),
    show("<<_:32>> & <<_:64>>  ", erl_types:t_inf(erl_types:t_bitstr(0,32),
                                                  erl_types:t_bitstr(0,64))),   % none()
    show("<<_:32>> & binary()  ", erl_types:t_inf(erl_types:t_bitstr(0,32),
                                                  erl_types:t_bitstr(8,0))),    % <<_:32>>
    show("<<_:_*3>> & <<_:_*5>>", erl_types:t_inf(erl_types:t_bitstr(3,0),
                                                  erl_types:t_bitstr(5,0))).    % <<_:_*15>>

%% ---------------------------------------------------------------------------
%% 5. Subtraction has no complement in this domain.
%% ---------------------------------------------------------------------------
subtraction() ->
    io:format("~n=== 5. subtraction — no complement ===~n"),
    show("binary() - <<_:32>>   ", erl_types:t_subtract(erl_types:t_bitstr(8,0),
                                                        erl_types:t_bitstr(0,32))),
        % => binary()      -- the 32-bit case was NOT removed
    show("bitstring() - binary()", erl_types:t_subtract(erl_types:t_bitstr(1,0),
                                                        erl_types:t_bitstr(8,0))).
        % => bitstring()

%% ---------------------------------------------------------------------------
%% 6. The consequence: ticket 04's residual never terminates over binaries.
%%
%%    The damage is done at UNION, not at subtraction. Subtraction walks the
%%    base forward correctly — but the union already widened the declared type
%%    into an infinite progression, so the residual never reaches none().
%%
%%    The atom control is the same shape with an exact algebra, and terminates.
%% ---------------------------------------------------------------------------
residual() ->
    io:format("~n=== 6. residual over a closed binary union (the WebSocket-frame shape) ===~n"),
    Declared = erl_types:t_sup(erl_types:t_bitstr(0,32), erl_types:t_bitstr(0,64)),
    show("declared <<_:32>> | <<_:64>>", Declared),               % <<_:32,_:_*32>>
    io:format("  does 96 bits inhabit it?  ~p  <-- union already lost the type~n",
              [erl_types:t_is_subtype(erl_types:t_bitstr(0,96), Declared)]),   % true
    R1 = erl_types:t_subtract(Declared, erl_types:t_bitstr(0,32)),
    show("  after clause <<_:32>>       ", R1),                   % <<_:64,_:_*32>>
    R2 = erl_types:t_subtract(R1, erl_types:t_bitstr(0,64)),
    show("  after clause <<_:64>>       ", R2),                   % <<_:96,_:_*32>>
    io:format("  exhaustive?               ~p~n", [erl_types:t_is_none(R2)]),  % false

    io:format("~n  control — same shape over atoms, where the algebra is exact:~n"),
    A  = erl_types:t_sup(erl_types:t_atom(a), erl_types:t_atom(b)),
    A1 = erl_types:t_subtract(A, erl_types:t_atom(a)),
    A2 = erl_types:t_subtract(A1, erl_types:t_atom(b)),
    show("  declared :a | :b            ", A),                    % 'a' | 'b'
    show("  after clause :a             ", A1),                   % 'b'
    show("  after clause :b             ", A2),                   % none()
    io:format("  exhaustive?               ~p~n", [erl_types:t_is_none(A2)]).  % true

%% ---------------------------------------------------------------------------
%% 7. Subsumption is NOT indiscriminability. Ticket 09 §4 errors on the second
%%    and must not error on the first.
%% ---------------------------------------------------------------------------
subsumption_vs_overlap() ->
    io:format("~n=== 7. subsumption vs overlap ===~n"),
    Fixed = erl_types:t_bitstr(0, 32),   % <<_:32>>
    Open  = erl_types:t_bitstr(8, 32),   % <<_:32,_:_*8>>
    U3    = erl_types:t_bitstr(3, 0),    % <<_:_*3>>
    U5    = erl_types:t_bitstr(5, 0),    % <<_:_*5>>
    sub("<<_:32>> <: <<_:32,_:_*8>>", Fixed, Open),               % true  -> absorbs, LEGAL
    show("  their union             ", erl_types:t_sup(Fixed, Open)),  % <<_:32,_:_*8>>
    sub("<<_:_*3>> <: <<_:_*5>>     ", U3, U5),                   % false
    sub("<<_:_*5>> <: <<_:_*3>>     ", U5, U3),                   % false
    show("  their intersection      ", erl_types:t_inf(U3, U5)).  % <<_:_*15>> -> overlap,
                                                                  % neither contains the
                                                                  % other: INDISCRIMINABLE
show(Label, T)  -> io:format("~s = ~s~n", [Label, erl_types:t_to_string(T)]).
sub(Label, A, B) -> io:format("~s : ~p~n", [Label, erl_types:t_is_subtype(A, B)]).
