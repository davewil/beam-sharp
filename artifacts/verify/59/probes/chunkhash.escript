#!/usr/bin/env escript
%% chunkhash.escript BEAM -> prints md5 of Code chunk, and of whole file
main([B]) ->
    {ok, {_, [{"Code", C}, {"LocT", L}, {"ExpT", E}, {"AtU8", A}]}} = beam_lib:chunks(B, ["Code","LocT","ExpT","AtU8"]),
    {ok, Bin} = file:read_file(B),
    io:format("~s code=~s loct=~s expt=~s atoms=~s file=~s~n", [filename:basename(B), h(C), h(L), h(E), h(A), h(Bin)]).
h(X) -> binary:part(binary:encode_hex(crypto:hash(md5, X)), 0, 8).
