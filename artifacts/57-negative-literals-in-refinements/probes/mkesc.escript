#!/usr/bin/env escript
main([Ebin, Out]) ->
    Fs = [{"bsc/ebin/" ++ filename:basename(F), element(2, file:read_file(F))}
          || F <- filelib:wildcard(Ebin ++ "/*.beam") ++ [Ebin ++ "/bsc.app"]],
    ok = escript:create(Out, [shebang, {emu_args, "-escript main bsc"}, {archive, Fs, []}]).
