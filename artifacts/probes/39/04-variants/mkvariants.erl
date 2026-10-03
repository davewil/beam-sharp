%% Builds timing variants. Each variant is the SAME program with one thing changed, renamed to a
%% distinct module so all can be timed in one VM.  Usage: mkvariants:main([BuildDir, OutDir])
-module(mkvariants).
-export([main/1]).
main([Build, Out]) ->
    file:make_dir(Out),
    {ok, Bs} = file:consult(Build ++ "/Day01.abstr"),
    {ok, ErlForms0} = epp:parse_file("../../../../aoc/bench/bench_erl.erl", []),
    ErlForms = [F || F <- ErlForms0, element(1,F) =/= eof],
    GleamSrc = Build ++ "/gleam/build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.erl",
    {ok, GForms0} = epp:parse_file(GleamSrc, []),
    GForms = [F || F <- GForms0, element(1,F) =/= eof],
    NoSpec = fun(Fs) -> [F || F <- Fs, not is_spec(F)] end,
    Inline = fun(Fs) -> insert_attr(Fs, {attribute,0,compile,inline}) end,
    NoInline = fun(Fs) -> [case F of {attribute,A,compile,L} when is_list(L) -> {attribute,A,compile,L -- [inline]}; _ -> F end || F <- Fs] end,
    NarrowSpec = fun(Fs) -> [narrow(F) || F <- Fs] end,
    GuardFact = fun(Fs) -> [guard_fact(F) || F <- Fs] end,
    V = [
     {e0_erlang,            erl, ErlForms,                   [debug_info]},
     {e1_erlang_no_type,    erl, ErlForms,                   [debug_info, no_type_opt]},
     {e2_erlang_inline,     erl, Inline(ErlForms),           [debug_info]},
     {b0_bs_as_is,          bs,  Bs,                         [debug_info]},
     {b1_bs_no_specs,       bs,  NoSpec(Bs),                 [debug_info]},
     {b2_bs_no_type,        bs,  Bs,                         [debug_info, no_type_opt]},
     {b3_bs_inline,         bs,  Inline(Bs),                 [debug_info]},
     {b4_bs_narrow_spec,    bs,  NarrowSpec(Bs),             [debug_info]},
     {b5_bs_guard_fact,     bs,  GuardFact(Bs),              [debug_info]},
     {g0_gleam_as_is,       gl,  GForms,                     [debug_info]},
     {g1_gleam_minus_inline,gl,  NoInline(GForms),           [debug_info]}],
    [begin
       Forms = rename(Fs, Name),
       {ok, Name, Bin, Ws} = compile:noenv_forms(Forms, [binary, return_warnings, report_errors | Opts]),
       file:write_file(Out ++ "/" ++ atom_to_list(Name) ++ ".beam", Bin),
       %% also an .S listing of each
       {ok, Name, Asm} = compile:noenv_forms(Forms, [to_asm | Opts]),
       {ok, Fd} = file:open(Out ++ "/" ++ atom_to_list(Name) ++ ".S", [write]),
       beam_listing:module(Fd, Asm), file:close(Fd),
       io:format("built ~-24s kind=~p warnings=~p size=~p~n", [Name, Kind, length(Ws), byte_size(Bin)])
     end || {Name, Kind, Fs, Opts} <- V],
    halt().
is_spec({attribute,_,spec,_}) -> true; is_spec(_) -> false.
rename(Fs, N) -> [case F of {attribute,A,module,_} -> {attribute,A,module,N}; _ -> F end || F <- Fs].
insert_attr(Fs, Attr) -> {A, [M|B]} = lists:splitwith(fun(F) -> element(3,F) =/= module orelse element(1,F) =/= attribute end, Fs),
                         A ++ [M, Attr | B].
narrow({attribute,A,spec,{{'Wrap',1},[{type,L,'fun',[Args,_Ret]}]}}) ->
    {attribute,A,spec,{{'Wrap',1},[{type,L,'fun',[Args,{type,L,range,[{integer,L,0},{integer,L,99}]}]}]}};
narrow(F) -> F.
%% Spin's `Next = Wrap(..)`  ==>  Next = case Wrap(..) of R when R >= 0, R =< 99 -> R end
guard_fact({function,A,'Spin',4,Cs}) -> {function,A,'Spin',4,[gf(C) || C <- Cs]};
guard_fact(F) -> F.
gf({clause,A,P,G,Body}) -> {clause,A,P,G,[gf_e(E) || E <- Body]}.
gf_e({match,A,{var,_,'Next'}=V,{call,_,{atom,_,'Wrap'},_}=Call}) ->
    R = {var,0,'R'},
    {match,A,V,{'case',0,Call,[{clause,0,[R],[[{op,0,'>=',R,{integer,0,0}},{op,0,'=<',R,{integer,0,99}}]],[R]}]}};
gf_e(E) -> E.
