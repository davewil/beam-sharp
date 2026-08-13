%%% PROTOTYPE 26a -- what a record erasure costs at the boundary.
%%%
%%% For ticket 26 (data modelling). Ticket 18 measured the TUPLE discriminator at +13 bytes
%%% of the Code chunk and asserted, without measuring, that "a map erasure's discriminator is
%%% strictly larger". This produces that number, and one ticket 18 could not have known to
%%% ask for: how each discriminator SCALES with the record's field count.
%%%
%%% Method is 18a's, deliberately, so the numbers compose with it:
%%%   - module names are equal length (the name lands in the atom table and CInf chunk),
%%%   - every module holds exactly one exported function plus synthesised module_info/0,1,
%%%     so the Code-chunk delta IS that function's own bytecode delta,
%%%   - compiled `deterministic`,
%%%   - a noise floor of two byte-identical modules under different names.
%%%
%%%   erlc -o /tmp/26a 26a_record_erasure_cost.erl
%%%   erl -noshell -pa /tmp/26a -eval "'26a_record_erasure_cost':go(), halt()."

-module('26a_record_erasure_cost').
-export([go/0]).

-include_lib("kernel/include/file.hrl").

-define(REPS, 2000000).

go() ->
    Dir = "/tmp/26a_variants",
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    true = code:add_patha(Dir),
    banner("PROTOTYPE 26a -- record erasure cost, OTP " ++ erlang:system_info(otp_release)),
    io:format("erts               : ~s~n", [erlang:system_info(version)]),
    io:format("compiler           : ~s~n", [compiler_vsn()]),
    io:format("compile options    : ~p~n", [copts(Dir)]),
    io:format("reps per timing    : ~b~n", [?REPS]),
    Vs = build_variants(Dir),
    section_1_size(Vs),
    section_2_scaling(Vs),
    section_3_time(Vs),
    section_4_semantics(),
    section_5_json(),
    ok.

%% ===========================================================================================
%% The variants.
%%
%% Every one is `amt/1`, projecting the `total` field out of a three- or eight-field record.
%% The three-field record is {order, Id, Total} / #{id, total, status} -- ticket 26's own
%% worked example. The eight-field pair exists only to expose scaling.

variants() ->
    [%% ---- noise floor: two byte-identical modules under different names -----------------
     {nf_a, tup3, "rc_nf3_a", "amt(X) -> element(3, X)."},
     {nf_b, tup3, "rc_nf3_b", "amt(X) -> element(3, X)."},

     %% ---- 3 fields, tuple erasure ------------------------------------------------------
     {tu3_u, tup3, "rc_tu3_u", "amt(X) -> element(3, X)."},
     {tu3_g, tup3, "rc_tu3_g",
      "amt(X) when is_tuple(X), tuple_size(X) =:= 3, element(1, X) =:= order ->\n"
      "    element(3, X)."},

     %% ---- 3 fields, map erasure, SHAPE ONLY (exact field set) --------------------------
     %% Exactness needs map_size: an Erlang map pattern matches a map with EXTRA keys, and
     %% ticket 27 sec7 declined row polymorphism, so a record type is an exact field set.
     {mp3_u, map3, "rc_mp3_u", "amt(X) -> map_get(total, X)."},
     {mp3_g, map3, "rc_mp3_g",
      "amt(X) when is_map(X), map_size(X) =:= 3,\n"
      "           is_map_key(id, X), is_map_key(total, X), is_map_key(status, X) ->\n"
      "    map_get(total, X)."},

     %% ---- 3 fields, map erasure, SHAPE + VALUE tests -----------------------------------
     %% Ticket 26's discriminability case: two record types with the SAME field names differ
     %% only in their value types, so the guard must inspect values.
     {mv3_g, map3, "rc_mv3_g",
      "amt(X) when is_map(X), map_size(X) =:= 3,\n"
      "           is_map_key(id, X), is_map_key(total, X), is_map_key(status, X),\n"
      "           is_integer(map_get(id, X)), is_integer(map_get(total, X)) ->\n"
      "    map_get(total, X)."},

     %% ---- 3 fields, TAGGED map (the Elixir-struct shape) -------------------------------
     %% map_get/2 on an absent key makes the whole guard fail, so one test is the entire
     %% discriminator -- no is_map, no map_size, no per-field is_map_key.
     {tg3_g, mtg3, "rc_tg3_g",
      "amt(X) when map_get('__type__', X) =:= order ->\n"
      "    map_get(total, X)."},

     %% ---- 8 fields: the same three discriminators, to expose scaling --------------------
     {tu8_u, tup8, "rc_tu8_u", "amt(X) -> element(3, X)."},
     {tu8_g, tup8, "rc_tu8_g",
      "amt(X) when is_tuple(X), tuple_size(X) =:= 9, element(1, X) =:= order ->\n"
      "    element(3, X)."},

     {mp8_u, map8, "rc_mp8_u", "amt(X) -> map_get(total, X)."},
     {mp8_g, map8, "rc_mp8_g",
      "amt(X) when is_map(X), map_size(X) =:= 8,\n"
      "           is_map_key(id, X), is_map_key(total, X), is_map_key(status, X),\n"
      "           is_map_key(f4, X), is_map_key(f5, X), is_map_key(f6, X),\n"
      "           is_map_key(f7, X), is_map_key(f8, X) ->\n"
      "    map_get(total, X)."},

     {tg8_g, mtg8, "rc_tg8_g",
      "amt(X) when map_get('__type__', X) =:= order ->\n"
      "    map_get(total, X)."}].

%% Shape -> the argument the driver passes in.
arg(tup3) -> {order, 1, 2};
arg(map3) -> #{id => 1, total => 2, status => open};
arg(mtg3) -> #{'__type__' => order, id => 1, total => 2};
arg(tup8) -> {order, 1, 2, 4, 5, 6, 7, 8, 9};
arg(map8) -> #{id => 1, total => 2, status => open,
               f4 => 4, f5 => 5, f6 => 6, f7 => 7, f8 => 8};
arg(mtg8) -> #{'__type__' => order, id => 1, total => 2,
               f4 => 4, f5 => 5, f6 => 6, f7 => 7, f8 => 8}.

%% {Caption, UnguardedKey, GuardedKey}
pairs() ->
    [{"NOISE FLOOR: two identical unguarded modules",        nf_a,  nf_b},
     {"3f tuple  discriminator (is_tuple+size+element)",     tu3_u, tu3_g},
     {"3f map    discriminator (shape only, exact set)",     mp3_u, mp3_g},
     {"3f map    discriminator (shape + 2 value tests)",     mp3_u, mv3_g},
     {"3f tagged map discriminator (one map_get)",           mp3_u, tg3_g},
     {"8f tuple  discriminator (is_tuple+size+element)",     tu8_u, tu8_g},
     {"8f map    discriminator (shape only, exact set)",     mp8_u, mp8_g},
     {"8f tagged map discriminator (one map_get)",           mp8_u, tg8_g}].

%% ===========================================================================================

section_1_size(Vs) ->
    banner("1. Code size on disk -- the number ticket 18 owed"),
    io:format("~-10s ~8s ~8s ~8s ~8s ~8s~n",
              ["module", "file", "Code", "AtU8", "ImpT", "instrs"]),
    [begin
         #{mod := M} = maps:get(K, Vs),
         {F, C, A, I, N} = sizes(M),
         io:format("~-10s ~8b ~8b ~8b ~8b ~8b~n", [M, F, C, A, I, N])
     end || {K, _, _, _} <- variants()],
    io:format("~n~-52s ~16s ~18s ~8s~n", ["pair", ".beam file", "Code chunk", "instrs"]),
    [begin
         #{mod := Mu} = maps:get(U, Vs),
         #{mod := Mg} = maps:get(G, Vs),
         {Fu, Cu, _, _, Nu} = sizes(Mu),
         {Fg, Cg, _, _, Ng} = sizes(Mg),
         io:format("~-52s ~16s ~18s ~8s~n",
                   [Cap, pct(Fg - Fu, Fu), pct(Cg - Cu, Cu), signed(Ng - Nu)])
     end || {Cap, U, G} <- pairs()],
    ok.

section_2_scaling(Vs) ->
    banner("2. How each discriminator SCALES with field count"),
    Get = fun(K) -> #{mod := M} = maps:get(K, Vs), {_, C, _, _, _} = sizes(M), C end,
    T3 = Get(tu3_g) - Get(tu3_u),
    T8 = Get(tu8_g) - Get(tu8_u),
    M3 = Get(mp3_g) - Get(mp3_u),
    M8 = Get(mp8_g) - Get(mp8_u),
    G3 = Get(tg3_g) - Get(mp3_u),
    G8 = Get(tg8_g) - Get(mp8_u),
    io:format("~-32s ~10s ~10s ~12s~n", ["discriminator", "3 fields", "8 fields", "per field"]),
    io:format("~-32s ~10s ~10s ~12s~n",
              ["tuple (tag + arity)", signed(T3), signed(T8), fmt1((T8 - T3) / 5)]),
    io:format("~-32s ~10s ~10s ~12s~n",
              ["map, exact field set", signed(M3), signed(M8), fmt1((M8 - M3) / 5)]),
    io:format("~-32s ~10s ~10s ~12s~n",
              ["tagged map (one map_get)", signed(G3), signed(G8), fmt1((G8 - G3) / 5)]),
    io:format("~nBytes of the Code chunk. 'per field' is the slope between the two widths.~n"
              "Ticket 18 emits this guard on EVERY exported function taking a record, and~n"
              "unconditionally wherever the value feeds a codegen obligation, so a slope~n"
              "that is not flat is a cost the whole language pays.~n"),
    ok.

section_3_time(Vs) ->
    banner("3. Match and projection time (3-field record)"),
    io:format("The ticket asserts maps are 'slower to match'. Measured, not assumed.~n"),
    io:format("Three runs; read a difference only if it exceeds the spread WITHIN a row.~n~n"),
    io:format("~-34s ~12s ~12s ~12s ~12s~n",
              ["variant", "run 1", "run 2", "run 3", "ns/call"]),
    Keys = [{tu3_u, "tuple  element/3, unguarded"},
            {tu3_g, "tuple  element/3, guarded"},
            {mp3_u, "map    map_get,   unguarded"},
            {mp3_g, "map    map_get,   guarded"},
            {mv3_g, "map    map_get,   guarded+values"},
            {tg3_g, "tagged map,       guarded"}],
    [begin
         #{drv := D, shape := S} = maps:get(K, Vs),
         A = arg(S),
         Ts = [time_us(D, A) || _ <- [1, 2, 3]],
         [T1, T2, T3] = Ts,
         Best = lists:min(Ts),
         io:format("~-34s ~12b ~12b ~12b ~12.2f~n",
                   [Cap, T1, T2, T3, (Best * 1000) / ?REPS])
     end || {K, Cap} <- Keys],
    io:format("~nMicroseconds for the whole loop; ns/call from the fastest of the three.~n"),
    ok.

section_4_semantics() ->
    banner("4. Term-model facts the erasure choice turns on"),

    io:format("--- 4.1 does a map PATTERN match a map with extra keys? ---~n"),
    Extra = #{id => 1, total => 2, status => open, sneaked_in => true},
    R1 = case Extra of #{id := _, total := _, status := _} -> matched; _ -> no_match end,
    io:format("  #{id := _, total := _, status := _} vs a 4-key map : ~p~n", [R1]),
    io:format("  => a map pattern is OPEN. Ticket 27 sec7 declined row polymorphism, so a~n"
              "     record type is an EXACT field set -- which the pattern alone cannot say.~n"),
    R2 = case Extra of
             X when is_map(X), map_size(X) =:= 3 -> matched;
             _ -> no_match
         end,
    io:format("  same map, with map_size(X) =:= 3 added               : ~p~n", [R2]),

    io:format("~n--- 4.2 does a TUPLE pattern match a wider tuple? ---~n"),
    R3 = case {order, 1, 2, 99} of {order, _, _} -> matched; _ -> no_match end,
    io:format("  {order, _, _} vs {order, 1, 2, 99}                   : ~p~n", [R3]),
    io:format("  => a tuple pattern is CLOSED. Arity is exact for free.~n"),

    io:format("~n--- 4.3 map_get/2 in a guard, on an ABSENT key ---~n"),
    %% Built at runtime so the compiler cannot constant-fold the absent key away: what is
    %% being measured is the RUNTIME behaviour of map_get/2 inside a guard, not the
    %% compiler's ability to see through this particular literal.
    Opaque = opaque_map(),
    R4 = case Opaque of
             Y when map_get('__type__', Y) =:= order -> matched;
             _ -> guard_failed_silently
         end,
    io:format("  guard `map_get('__type__', X) =:= order`, key absent : ~p~n", [R4]),
    Tagged = maps:put('__type__', order, Opaque),
    R4b = case Tagged of
              Z when map_get('__type__', Z) =:= order -> matched;
              _ -> guard_failed_silently
          end,
    io:format("  same guard, key present and equal                    : ~p~n", [R4b]),
    io:format("  => it fails the guard rather than raising, so ONE map_get is a complete~n"
              "     discriminator for a tagged map: no is_map, no map_size, no is_map_key.~n"),

    io:format("~n--- 4.4 is field ORDER observable in each erasure? ---~n"),
    io:format("  #{b => 1, a => 2} =:= #{a => 2, b => 1}             : ~p~n",
              [#{b => 1, a => 2} =:= #{a => 2, b => 1}]),
    io:format("  {order,1,2}       =:= {order,2,1}                   : ~p~n",
              [{order, 1, 2} =:= {order, 2, 1}]),
    io:format("  => ticket 09 says a record type IS its field SET. A set has no order, so a~n"
              "     tuple erasure must invent a canonical one and put it in the wire format.~n"),

    io:format("~n--- 4.5 what an Elixir struct looks like coming in (ticket 06) ---~n"),
    Struct = #{'__struct__' => 'Elixir.Order', id => 1, total => 2},
    io:format("  an Elixir %Order{} term                             : ~p~n", [Struct]),
    io:format("  map_size                                            : ~p~n", [map_size(Struct)]),
    io:format("  => it is a map with one extra key. Under a map erasure it arrives as a~n"
              "     record with an extra field; under a tuple erasure it needs conversion.~n"),
    ok.

section_5_json() ->
    banner("5. json:encode/1 -- ticket 16 sec4's generated encoder"),
    io:format("Ticket 16 established json:encode/1 REFUSES tuples at any depth, and made the~n"
              "encoder a codegen obligation. A record is the main thing anyone serialises.~n~n"),
    show_encode("map    #{id=>1,total=>2,status=>open}", #{id => 1, total => 2, status => open}),
    show_encode("tuple  {order,1,2}", {order, 1, 2}),
    show_encode("tagged map (__type__ key)", #{'__type__' => order, id => 1, total => 2}),
    show_encode("nested: map holding a tuple", #{id => 1, at => {2026, 8, 13}}),
    ok.

show_encode(Label, Term) ->
    R = try iolist_to_binary(json:encode(Term))
        catch C:E -> {caught, C, brief(E)}
        end,
    io:format("  ~-40s -> ~p~n", [Label, R]).

brief(E) when is_tuple(E), tuple_size(E) > 0 -> element(1, E);
brief(E) -> E.

%% A map the compiler cannot fold: its contents come from the runtime.
opaque_map() ->
    maps:from_list([{K, V} || {K, V} <- [{id, erlang:system_time(millisecond)},
                                         {total, 2}]]).

%% ===========================================================================================
%% Generation, compilation, measurement

build_variants(Dir) ->
    maps:from_list(
      [begin
           Src = io_lib:format("-module(~s).~n-export([amt/1]).~n~n~s~n", [Mod, Body]),
           ok = compile_text(Dir, Mod, Src),
           Drv = [$d | tl(Mod)],
           ok = compile_text(Dir, Drv, driver_src(Drv, Mod)),
           {module, _} = code:load_file(list_to_atom(Mod)),
           {module, _} = code:load_file(list_to_atom(Drv)),
           {Key, #{mod => Mod, drv => list_to_atom(Drv), shape => Shape}}
       end
       || {Key, Shape, Mod, Body} <- variants()]).

%% The driver holds a static remote call so it cannot be inlined away, and returns the live
%% accumulator. `band` keeps it off bignums. Identical in every driver.
driver_src(Drv, Mod) ->
    io_lib:format(
      "-module(~s).~n"
      "-export([loop/3]).~n~n"
      "loop(0, _R, Acc) -> Acc;~n"
      "loop(N, R, Acc) -> loop(N - 1, R, (Acc + ~s:amt(R)) band 16#FFFF).~n",
      [Drv, Mod]).

compile_text(Dir, Mod, Src) ->
    File = filename:join(Dir, Mod ++ ".erl"),
    ok = file:write_file(File, unicode:characters_to_binary(Src)),
    case compile:file(File, copts(Dir)) of
        {ok, _}       -> ok;
        {error, E, W} -> erlang:error({compile_failed, Mod, E, W})
    end.

copts(Dir) -> [{outdir, Dir}, deterministic, return_errors].

time_us(Drv, Arg) ->
    _ = Drv:loop(50000, Arg, 0),          %% warm the JIT
    erlang:garbage_collect(),
    {T, _} = timer:tc(fun() -> Drv:loop(?REPS, Arg, 0) end),
    T.

sizes(Mod) ->
    Beam = code:which(list_to_atom(Mod)),
    {ok, {_, Chunks}} = beam_lib:chunks(Beam, ["Code", "AtU8", "ImpT"]),
    C = byte_size(proplists:get_value("Code", Chunks)),
    A = byte_size(proplists:get_value("AtU8", Chunks)),
    I = byte_size(proplists:get_value("ImpT", Chunks)),
    {ok, #file_info{size = F}} = file:read_file_info(Beam),
    {F, C, A, I, instr_count(Mod)}.

%% Count emitted BEAM instructions for amt/1 only, from the module's own assembly.
instr_count(Mod) ->
    Dir = filename:dirname(code:which(list_to_atom(Mod))),
    File = filename:join(Dir, Mod ++ ".erl"),
    {ok, _} = compile:file(File, [to_asm, {outdir, Dir}, deterministic, return_errors]),
    {ok, Bin} = file:read_file(filename:join(Dir, Mod ++ ".S")),
    count_amt(binary_to_list(Bin)).

%% The .S file is a FLAT sequence of terms: `{function, amt, 1, 2}.` is followed by the
%% instructions as sibling terms, not as a nested list. So count the terms between the
%% amt/1 header and the next function header, skipping the label/func_info preamble that
%% every function carries identically.
count_amt(Str) ->
    Forms = scan_terms(Str, []),
    count_after(Forms, false, 0).

count_after([], _, N) -> N;
count_after([{function, amt, 1, _} | T], _, N) -> count_after(T, true, N);
count_after([{function, _, _, _} | T], _, N) -> count_after(T, false, N);
count_after([_ | T], false, N) -> count_after(T, false, N);
count_after([H | T], true, N) ->
    case H of
        {label, _}     -> count_after(T, true, N);
        {func_info, _, _, _} -> count_after(T, true, N);
        _              -> count_after(T, true, N + 1)
    end.

scan_terms(Str, Acc) ->
    case erl_scan:tokens([], Str, 1) of
        {done, {ok, Toks, _}, Rest} ->
            case erl_parse:parse_term(Toks) of
                {ok, T}    -> scan_terms(Rest, [T | Acc]);
                {error, _} -> scan_terms(Rest, Acc)
            end;
        _ -> lists:reverse(Acc)
    end.

compiler_vsn() ->
    _ = application:load(compiler),
    case application:get_key(compiler, vsn) of
        {ok, V} -> V;
        _       -> "unknown"
    end.

%% ===========================================================================================

banner(S) -> io:format("~n~s~n~s~n~s~n", [string:copies("=", 91), S, string:copies("=", 91)]).

signed(N) when N >= 0 -> lists:flatten(io_lib:format("+~b", [N]));
signed(N)             -> lists:flatten(io_lib:format("~b", [N])).

fmt1(F) ->
    Sign = case F >= 0 of true -> "+"; false -> "-" end,
    Sign ++ lists:flatten(io_lib:format("~.1f", [abs(F) * 1.0])).

pct(D, Base) when Base > 0 ->
    lists:flatten(io_lib:format("~s (~s%)", [signed(D), fmt1(D * 100 / Base)]));
pct(D, _) -> signed(D).
