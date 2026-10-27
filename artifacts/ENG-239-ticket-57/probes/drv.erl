%% Driver: source text -> real bs_lexer(scratch, lines only) -> real bs_parser -> bs_lower -> real bs_check.
-module(drv).
-export([run/1, parse/1, shape/1]).
parse(Src) ->
    {ok, T, _} = bs_lexer:string(Src),
    {ok, D} = bs_parser:parse(T),
    bs_lower:valves(D).
run(Src) ->
    try
        D = parse(Src),
        case bs_check:check(D) of
            {ok, _, _}    -> accepted;
            {error, Errs} -> {refused, [short(E) || E <- Errs]}
        end
    catch C:R:_ -> {crashed, C, R}
    end.
short({error, Line, Reason}) -> {Line, Reason};
short(E) -> E.
shape(Src) -> lists:filter(fun(D) -> element(1, D) =:= type_refined end, parse(Src)).
