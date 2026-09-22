%%% PROTOTYPE 59a -- what ticket 59's two guards cost on a PRIVATE function, measured
%%% independently rather than cited from 18a/26a.
%%%
%%% For ticket 59 (boundary guard scope asymmetry). `bs_emit:guard_one/7` emits the record
%%% TAG test unconditionally (private functions included) and the int KIND+RANGE test only
%%% on exported functions. This measures, on a PRIVATE function shape, both directions:
%%%   - what removing the tag test would SAVE  (the "narrow" option)
%%%   - what adding the kind+range test would COST (the "widen" option)
%%%
%%% The guard bodies below are not invented -- they are copied verbatim from bsc's own
%%% emitted `.abstr` for `InnerRecord/1` and what `OuterOctet/1` carries (the guard
%%% `InnerOctet/1` would carry if the kind test applied to private functions too), read at
%%% /home/user/beam-sharp/artifacts/_probes/59/out/Probe59.abstr.
%%%
%%% Method is 18a's and 26a's, deliberately, so the numbers compose with theirs:
%%%   - module names are equal length WITHIN each pair (the name lands in the atom table and
%%%     the CInf chunk),
%%%   - every module holds exactly one function (`amt/1`) plus the synthesised
%%%     `module_info/0,1`, so the Code-chunk delta IS that function's own bytecode delta,
%%%   - compiled `deterministic`,
%%%   - a noise floor of two byte-identical modules under different (equal-length) names.
%%%
%%%   erlc -o /tmp/59a 59a_asymmetry_cost.erl
%%%   erl -noshell -pa /tmp/59a -eval "'59a_asymmetry_cost':go(), halt()."

-module('59a_asymmetry_cost').
-export([go/0]).

-include_lib("kernel/include/file.hrl").

go() ->
    Dir = "/tmp/59a_variants",
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    true = code:add_patha(Dir),
    banner("PROTOTYPE 59a -- boundary guard scope asymmetry, cost on a PRIVATE function, OTP "
           ++ erlang:system_info(otp_release)),
    io:format("erts               : ~s~n", [erlang:system_info(version)]),
    io:format("compiler           : ~s~n", [compiler_vsn()]),
    io:format("compile options    : ~p~n", [copts(Dir)]),
    Vs = build_variants(Dir),
    section_1_size(Vs),
    ok.

%% ===========================================================================================
%% The variants. Every one is `amt/1`. The guard text is copied verbatim from what bsc
%% emitted for InnerRecord/1 (the map_get/=:= tag test) and OuterOctet/1 (the is_integer +
%% range chain) in Probe59.abstr, so this is not a re-derivation of the guard shape, only of
%% its cost.

variants() ->
    [%% ---- noise floor: two byte-identical modules under equal-length names -------------
     {nf_a, "nf59_a_u", "amt(X) -> X."},
     {nf_b, "nf59_b_u", "amt(X) -> X."},

     %% ---- THE TAG TEST, as bsc emits it on InnerRecord/1 (private, unconditional today) -
     {rec_u, "rec_priv_u", "amt(X) -> map_get(total, X)."},
     {rec_g, "rec_priv_g",
      "amt(X) when map_get(kind, X) =:= order ->\n"
      "    map_get(total, X)."},

     %% ---- THE KIND+RANGE TEST, as bsc emits it on OuterOctet/1 (exported today; this is
     %% ---- what InnerOctet/1 would carry if the widen option were taken, since Octet's
     %% ---- declared type carries both a kind and a range) --------------------------------
     {int_u, "int_priv_u", "amt(X) -> X."},
     {int_g, "int_priv_g",
      "amt(X) when is_integer(X), X >= 0, X =< 255 ->\n"
      "    X."},

     %% ---- KIND ALONE (a plain, unrefined `int` parameter), to reconcile against 18a's
     %% ---- cited "+3-5 bytes per is_integer" -- that figure was for `int`, not `Octet` ----
     {kind_u, "kindonly_u", "amt(X) -> X."},
     {kind_g, "kindonly_g", "amt(X) when is_integer(X) ->\n    X."}
    ].

build_variants(Dir) ->
    maps:from_list(
      [begin
           ok = compile_text(Dir, Mod, io_lib:format("-module(~s).~n-export([amt/1]).~n~n~s~n", [Mod, Body])),
           {module, _} = code:load_file(list_to_atom(Mod)),
           {Key, Mod}
       end
       || {Key, Mod, Body} <- variants()]).

compile_text(Dir, Mod, Src) ->
    File = filename:join(Dir, Mod ++ ".erl"),
    ok = file:write_file(File, unicode:characters_to_binary(Src)),
    case compile:file(File, copts(Dir)) of
        {ok, _}       -> ok;
        {error, E, W} -> erlang:error({compile_failed, Mod, E, W})
    end.

copts(Dir) -> [{outdir, Dir}, deterministic, return_errors].

sizes(Mod) ->
    Beam = code:which(list_to_atom(Mod)),
    {ok, {_, Chunks}} = beam_lib:chunks(Beam, ["Code", "AtU8", "ImpT"]),
    C = byte_size(proplists:get_value("Code", Chunks)),
    A = byte_size(proplists:get_value("AtU8", Chunks)),
    I = byte_size(proplists:get_value("ImpT", Chunks)),
    {ok, #file_info{size = F}} = file:read_file_info(Beam),
    {F, C, A, I, instr_count(Mod)}.

instr_count(Mod) ->
    Dir = filename:dirname(code:which(list_to_atom(Mod))),
    File = filename:join(Dir, Mod ++ ".erl"),
    {ok, _} = compile:file(File, [to_asm, {outdir, Dir}, deterministic, return_errors]),
    {ok, Bin} = file:read_file(filename:join(Dir, Mod ++ ".S")),
    count_amt(binary_to_list(Bin)).

count_amt(Str) ->
    Forms = scan_terms(Str, []),
    count_after(Forms, false, 0).

count_after([], _, N) -> N;
count_after([{function, amt, 1, _} | T], _, N) -> count_after(T, true, N);
count_after([{function, _, _, _} | _], true, N) -> N;
count_after([_ | T], true, N) -> count_after(T, true, N + 1);
count_after([_ | T], false, N) -> count_after(T, false, N).

scan_terms(Str, Acc) ->
    case erl_scan:tokens([], Str, 1) of
        {done, {ok, Toks, _}, Rest} ->
            case erl_parse:parse_term(Toks) of
                {ok, Term} -> scan_terms(Rest, [Term | Acc]);
                _          -> scan_terms(Rest, Acc)
            end;
        {more, _} -> lists:reverse(Acc);
        _ -> lists:reverse(Acc)
    end.

section_1_size(Vs) ->
    banner("1. Code size on disk"),
    io:format("~-14s ~10s ~10s ~10s ~10s ~8s~n",
              ["module", "file", "Code", "AtU8", "ImpT", "instrs"]),
    Rows = [{K, sizes(M)} || {K, M} <- maps:to_list(Vs)],
    [io:format("~-14s ~10b ~10b ~10b ~10b ~8b~n", [K, F, C, A, I, N])
     || {K, {F, C, A, I, N}} <- lists:sort(Rows)],
    NfA = fetch(nf_a, Rows), NfB = fetch(nf_b, Rows),
    RecU = fetch(rec_u, Rows), RecG = fetch(rec_g, Rows),
    IntU = fetch(int_u, Rows), IntG = fetch(int_g, Rows),
    KindU = fetch(kind_u, Rows), KindG = fetch(kind_g, Rows),
    io:format("~n~-46s ~12s ~14s~n", ["pair", ".beam file", "Code chunk"]),
    delta("noise floor (nf_a vs nf_b)", NfA, NfB),
    delta("TAG test on private (rec_priv_g - rec_priv_u)", RecU, RecG),
    delta("KIND+RANGE test on private (int_priv_g - int_priv_u)", IntU, IntG),
    delta("KIND ALONE, plain int, cf. 18a's +3-5B (kindonly)", KindU, KindG),
    io:format("~nInterpretation:~n"),
    io:format("  TAG test row       = what NARROWING (exported-only tag test) would SAVE per~n"
              "                       private record parameter.~n"),
    io:format("  KIND+RANGE test row = what WIDENING (unconditional int test) would COST per~n"
              "                        private refined-int parameter.~n"),
    ok.

fetch(Key, Rows) -> proplists:get_value(Key, Rows).

delta(Label, {F1,C1,_,_,N1}, {F2,C2,_,_,N2}) ->
    io:format("~-46s ~s (~s) ~s (~s) ~s instrs~n",
              [Label, signed(F2-F1), pct(F2-F1,F1), signed(C2-C1), pct(C2-C1,C1), signed(N2-N1)]).

signed(N) when N >= 0 -> io_lib:format("+~b", [N]);
signed(N) -> io_lib:format("~b", [N]).

pct(_, 0) -> "n/a";
pct(D, Base) -> io_lib:format("~.1f%", [100.0 * D / Base]).

compiler_vsn() ->
    application:load(compiler),
    case application:get_key(compiler, vsn) of
        {ok, Vsn} -> Vsn;
        undefined -> "unknown"
    end.

banner(Title) ->
    io:format("~n~s~n~s~n", [Title, lists:duplicate(length(Title), $=)]).
