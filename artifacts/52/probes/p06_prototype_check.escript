#!/usr/bin/env escript
%%! -pa /tmp/bsc52/ebin -pa /tmp/bsc52/ebinB
%% p06: a MODEL of the compiler delta, run on real B# files.  It is an out-of-tree script, not a patch:
%%   * parses with the repo's real lexer and a SCRATCH parser that accepts `using :M in :app { }` (p12 measured its
%%     grammar cost; build step: build_parser_b.sh), then
%%   * applies the pass the brief proposes to every `{foreign, ...}` declaration: code:which/1, then the .app file
%%     next to the beam, then compare with the declared application.
%% Usage: escript p06_prototype_check.escript FILE.bs...     (ERL_LIBS decides what is "present")
main(Files) -> [check_file(F) || F <- Files].

check_file(F) ->
    {ok, Bin} = file:read_file(F),
    {ok, Toks, _} = bs_lexer:string(binary_to_list(Bin)),
    {ok, Decls} = bs_parser:parse(Toks),
    Foreign = [case D of
                   {foreign, L, M, Sigs} -> {L, M, none, Sigs};
                   {foreign, L, M, App, Sigs} -> {L, M, App, Sigs}
               end || D <- Decls, element(1, D) =:= foreign],
    [check(F, L, M, App) || {L, M, App, _} <- Foreign].

check(F, L, M, Declared) ->
    Where = io_lib:format("~s:~p", [filename:basename(F), L]),
    case facts(M) of
        {present, preloaded, erts} -> say(Where, M, Declared, "ok    in OTP (erts, preloaded)");
        {present, Path, App} ->
            Otp = is_otp(Path),
            case {Otp, Declared, App} of
                {true, none, _}        -> say(Where, M, Declared, "ok    OTP application ~p needs no declaration", [App]);
                {_, none, _}           -> say(Where, M, Declared, "NEEDS  module is in application ~p, which is not OTP: write `in :~p`", [App, App]);
                {_, App, _}            -> say(Where, M, Declared, "ok    module is in declared application ~p", [App]);
                {_, Other, _}          -> say(Where, M, Declared, "ERROR  declared `in :~p` but the module belongs to application ~p", [Other, App])
            end;
        absent ->
            case Declared of
                none -> say(Where, M, Declared, "ERROR  module ~p is not on the code path (no application named, so no hint which to install)", [M]);
                _ -> say(Where, M, Declared, "ERROR  module ~p is not on the code path; declared application ~p is ~s", [M, Declared, app_state(Declared)])
            end
    end.

facts(M) ->
    case code:which(M) of
        preloaded -> {present, preloaded, erts};
        non_existing -> absent;
        P -> Ebin = filename:dirname(P),
             [AppFile | _] = filelib:wildcard(filename:join(Ebin, "*.app")),
             {ok, [{application, App, _}]} = file:consult(AppFile),
             {present, P, App}
    end.
is_otp(Path) -> string:prefix(Path, code:lib_dir()) =/= nomatch.
app_state(A) -> case code:lib_dir(A) of {error, _} -> "not on the path either"; D -> "at " ++ D end.
say(Where, M, Declared, Fmt) -> say(Where, M, Declared, Fmt, []).
say(Where, M, Declared, Fmt, Args) ->
    io:format("~-14s ~-26w declared=~-10w ~s~n", [Where, M, Declared, io_lib:format(Fmt, Args)]).
