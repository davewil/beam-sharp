#!/usr/bin/env escript
%% usage: mkvariants.escript <dbgdir> <outdir>
%% Builds, from the debug_info abstract code of the Erlang and beam-sharp modules, one beam per
%% variant. Every variant exports spin/4 (named 'spin' or 'Spin') so the loop can be timed alone.
main([Dbg, Out]) ->
    ok = filelib:ensure_dir(filename:join(Out, "x")),
    Erl = forms(filename:join(Dbg, "bench_erl.beam")),
    Bs  = forms(filename:join(Dbg, "Day01.beam")),
    Gl  = forms(filename:join(Dbg, "bench_gleam.beam")),
    V = [
     {v_erl,            Erl, spin, [], []},                       %% control: rebuilt from forms
     {v_erl_inline,     Erl, spin, [{compile,inline}], []},
     {v_erl_gint,       Erl, spin, [], [gint]},
     {v_erl_grange,     Erl, spin, [], [grange]},
     {v_erl_notypeopt,  Erl, spin, [], [{opt,no_type_opt}]},
     {v_erl_nossaopt,   Erl, spin, [], [{opt,no_ssa_opt}]},
     {v_erl_notr,       Erl, spin, [], [notr]},
     {v_bs,             Bs,  'Spin', [], []},
     {v_bs_inline,      Bs,  'Spin', [{compile,inline}], []},
     {v_bs_gint,        Bs,  'Spin', [], [gint]},
     {v_bs_grange,      Bs,  'Spin', [], [grange]},
     {v_bs_notr,        Bs,  'Spin', [], [notr]},
     {v_bs_inline_size, Bs,  'Spin', [{compile,inline}], [{opt,{inline_size,200}}]},
     {v_bs_inline_list, Bs,  'Spin', [{compile,{inline,[{'Wrap',1},{'Hit',1}]}}], []},
     {v_erl_inline_list,Erl, spin, [{compile,{inline,[{wrap,1},{hit,1}]}}], []},
     {v_erl_bswrap_inline, Erl, spin, [{compile,inline}], [{swap, Bs, 'Wrap', wrap}]},
     {v_bs_erlwrap_inline, Bs,  'Spin', [{compile,inline}], [{swap, Erl, wrap, 'Wrap'}]},
     {v_gl,             Gl,  spin, [], []},
     {v_gl_noinline,    Gl,  spin, [], [drop_inline]}
    ],
    [build(Out, X) || X <- V],
    ok.

forms(Beam) ->
    {ok,{_,[{abstract_code,{_,AC}}]}} = beam_lib:chunks(Beam,[abstract_code]),
    AC.

build(Out, {Name, Forms0, Spin, Attrs, Mods}) ->
    F1 = [case F of {attribute,L,module,_} -> {attribute,L,module,Name}; _ -> F end || F <- Forms0],
    F2 = case lists:member(drop_inline, Mods) of
             true -> [drop_inline(F) || F <- F1];
             false -> F1
         end,
    F3 = insert_after_module(F2, [{attribute,1,export,[{Spin,4}]}]
                                 ++ [{attribute,1,A,B} || {A,B} <- Attrs]),
    F3b = lists:foldl(fun({swap, SrcForms, From, To}, Fs) -> swap(Fs, SrcForms, From, To);
                         (_, Fs) -> Fs end, F3, Mods),
    F4 = lists:foldl(fun(gint,Fs)   -> guards(Fs, Spin, int);
                        (grange,Fs) -> guards(Fs, Spin, range);
                        (_,Fs)      -> Fs end, F3b, Mods),
    Opts0 = [binary, return_errors] ++ [O || {opt,O} <- Mods],
    Bin = case lists:member(notr, Mods) of
              true ->
                  {ok,_,Asm} = compile:forms(F4, [return_errors,'S']),
                  Asm1 = strip_tr(Asm),
                  {ok,_,B} = compile:forms(Asm1, [from_asm, binary, return_errors]), B;
              false ->
                  {ok,_,B} = compile:forms(F4, Opts0), B
          end,
    ok = file:write_file(filename:join(Out, atom_to_list(Name)++".beam"), Bin),
    io:format("built ~s (~p bytes)~n", [Name, byte_size(Bin)]).

insert_after_module(Forms, New) ->
    {Pre, [M|Post]} = lists:splitwith(fun({attribute,_,module,_}) -> false; (_) -> true end, Forms),
    Pre ++ [M] ++ New ++ Post.

drop_inline({attribute,_,compile,L}) when is_list(L) ->
    {attribute,1,compile,[X || X <- L, X =/= inline]};
drop_inline(F) -> F.

strip_tr({tr,R,_}) -> strip_tr(R);
strip_tr(T) when is_tuple(T) -> list_to_tuple([strip_tr(E) || E <- tuple_to_list(T)]);
strip_tr([H|T]) -> [strip_tr(H)|strip_tr(T)];
strip_tr(T) -> T.

%% add guards to every clause of Spin/4 over its variable parameters
guards(Forms, Spin, Kind) ->
    [case F of
         {function,L,Spin,4,Cs} -> {function,L,Spin,4,[guard_clause(C,Kind)||C<-Cs]};
         _ -> F
     end || F <- Forms].

guard_clause({clause,L,Pats,Gs,Body}, Kind) ->
    Tests = lists:append([tests(P,I,Kind) || {P,I} <- lists:zip(Pats,lists:seq(1,4))]),
    Gs1 = case Gs of [] -> [Tests]; _ -> [G ++ Tests || G <- Gs] end,
    {clause,L,Pats,Gs1,Body}.

tests({var,L,V}, I, int) when V =/= '_' -> [call(L,is_integer,[{var,L,V}])];
tests({var,L,V}, I, range) when V =/= '_' ->
    [call(L,is_integer,[{var,L,V}])] ++
    case I of
      1 -> [cmp(L,'>=',V,0), cmp(L,'=<',V,99)];
      2 -> [cmp(L,'>=',V,-1), cmp(L,'=<',V,1)];
      _ -> [cmp(L,'>=',V,0)]
    end;
tests(_, _, _) -> [].

call(L, F, As) -> {call,L,{atom,L,F},As}.
cmp(L, Op, V, N) -> {op,L,Op,{var,L,V},int(L,N)}.
int(L, N) when N < 0 -> {op,L,'-',{integer,L,-N}};
int(L, N) -> {integer,L,N}.

%% replace To/1's clauses in Forms with From/1's clauses from SrcForms (renamed to To)
swap(Forms, SrcForms, From, To) ->
    {function,_,From,1,Cs} = lists:keyfind(From, 3, [F || F={function,_,_,1,_} <- SrcForms]),
    [case F of
         {function,L,To,1,_} -> {function,L,To,1,Cs};
         _ -> F
     end || F <- Forms].
