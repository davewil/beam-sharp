#!/bin/sh
# (1) What the emitted .beam ALREADY records about the foreign module (imports chunk) and
#     whether OTP's own xref already answers "is the dependency present" after the fact.
# (2) Bytes added by a `-bs_requires` module attribute, in three spellings.
. "$(dirname "$0")/env.sh"
rm -rf $W/p09 && mkdir -p $W/p09 && cd $W/p09
cp -r $W/greet/Greet . && mkdir out
ERL_LIBS=$W/greeter_build/dev/lib $BSC -o out Greet >/dev/null 2>&1
cat > p09.escript <<'E'
#!/usr/bin/env escript
main([Abstr, Beam]) ->
    {ok, Forms0} = file:consult(Abstr),
    {ok, B0} = file:read_file(Beam),
    io:format("baseline Greet.beam = ~p bytes~n", [byte_size(B0)]),
    {ok, {_, [{imports, Imps}]}} = beam_lib:chunks(Beam, [imports]),
    io:format("beam_lib imports chunk (no extra emission): ~p~n", [Imps]),
    Variants = [{"none", []},
                {"-bs_requires([req]).", [{attribute,0,bs_requires,[req]}]},
                {"-bs_requires([{req,\"0.7.3\"}]).", [{attribute,0,bs_requires,[{req,"0.7.3"}]}]},
                {"-bs_requires([req,finch,jason]).", [{attribute,0,bs_requires,[req,finch,jason]}]},
                {"3 attrs: app + elixir + per-module", [{attribute,0,bs_requires,[req]},
                      {attribute,0,bs_requires,[elixir]}, {attribute,0,bs_requires,[jason]}]}],
    Base = size_of(Forms0, [], "/tmp/v52/p09"),
    [begin S = size_of(Forms0, Extra, "/tmp/v52/p09"),
           io:format("  ~-40s ~5w bytes  (+~w)~n", [Name, S, S - Base]) end || {Name, Extra} <- Variants],
    %% readable WITHOUT loading, as a release tool would
    F = fun(Extra) -> Fs = ins(Forms0, Extra),
            {ok, _, Bin} = compile:forms(Fs, [debug_info, binary]), Bin end,
    Bin = F([{attribute,0,bs_requires,[{req,"0.7.3"}]}]),
    {ok, {_, [{attributes, At}]}} = beam_lib:chunks(Bin, [attributes]),
    io:format("beam_lib:chunks(attributes) -> ~p~n", [At]),
    T = timer:tc(fun() -> [beam_lib:chunks(Bin, [attributes]) || _ <- lists:seq(1,1000)] end),
    io:format("reading attributes: ~.1f us per beam (1000 reads, in-memory)~n", [element(1,T)/1000]).
ins([M | Rest], Extra) -> [M | Extra] ++ Rest.
size_of(Forms0, Extra, _Dir) ->
    {ok, _, Bin} = compile:forms(ins(Forms0, Extra), [debug_info, binary]), byte_size(Bin).
E
escript p09.escript out/Greet.abstr out/Greet.beam
echo "== xref over the compiled beam: dependency absent vs present on the path (existing OTP tool, post-compile)"
cat > x.escript <<'E'
#!/usr/bin/env escript
main([Dir]) ->
    {ok, _} = xref:start(s), 
    xref:set_default(s, [{verbose,false},{warnings,false}]),
    case os:getenv("XREF_LIB") of "1" -> ok = xref:set_library_path(s, code_path); _ -> ok end,
    io:format("  library_path=~p~n", [xref:get_library_path(s)]),
    {ok, _} = xref:add_directory(s, Dir),
    {ok, U} = xref:analyze(s, undefined_function_calls),
    io:format("  undefined_function_calls: ~p~n", [U]).
E
echo "-- ERL_LIBS unset";  env -u ERL_LIBS escript x.escript out
echo "-- ERL_LIBS has greeter, xref default library path"; ERL_LIBS=$W/greeter_build/dev/lib escript x.escript out
echo "-- ERL_LIBS has greeter, xref library_path = code_path"; ERL_LIBS=$W/greeter_build/dev/lib XREF_LIB=1 escript x.escript out
echo "-- ERL_LIBS unset, xref library_path = code_path"; env -u ERL_LIBS XREF_LIB=1 escript x.escript out
