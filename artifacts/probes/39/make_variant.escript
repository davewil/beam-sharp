#!/usr/bin/env escript
%% usage: make_variant.escript FORMS OUTDIR (add_inline|strip_inline|none)
%% Recompiles an Abstract Format file with ONE change to its compile attributes and nothing else:
%%   add_inline   - appends {attribute,_,compile,[inline]}
%%   strip_inline - removes `inline` from every -compile(...) attribute
main([F, Out, Mode]) ->
    {ok, Raw} = file:read_file(F),
    Forms = case file:consult(F) of {ok, Fs} -> Fs; _ -> binary_to_term(Raw) end,
    Forms2 = case Mode of
        "none" -> Forms;
        "add_inline" ->
            insert_after_module(Forms, {attribute,0,compile,[inline]});
        "strip_inline" ->
            [case X of
                 {attribute,L,compile,Opts} when is_list(Opts) -> {attribute,L,compile,Opts -- [inline]};
                 _ -> X
             end || X <- Forms]
    end,
    {ok, M, Bin} = compile:forms(Forms2, []),
    ok = filelib:ensure_dir(filename:join(Out, "x")),
    ok = file:write_file(filename:join(Out, atom_to_list(M) ++ ".beam"), Bin),
    io:format("~s ~s~n", [M, Mode]).

insert_after_module([{attribute,_,module,_} = M | T], A) -> [M, A | T];
insert_after_module([H | T], A) -> [H | insert_after_module(T, A)].
