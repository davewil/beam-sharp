-module(disasm).
-export([go/2]).
go(Mod, File) ->
    {module, Mod} = code:ensure_loaded(Mod),
    Result = beam_disasm:file(code:which(Mod)),
    file:write_file(File, io_lib:format("~p~n", [Result])),
    ok.
