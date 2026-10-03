#!/usr/bin/env escript
%% Erlang/OTP: what does the PARSER hand over for `-5` in a pattern, a guard and an
%% expression, and who folds it?  (real erl_scan/erl_parse/erl_lint/erl_eval of this OTP)
main(_) ->
    io:format("OTP ~s~n", [erlang:system_info(otp_release)]),
    Forms = [
      "f(-5) -> a.",                       % pattern
      "f(2+3) -> a.",                      % constant arithmetic as a pattern
      "f(-(5)) -> a.",
      "f(X) when X >= -5 -> a.",           % guard comparison
      "f(X) when X >= 2+3 -> a.",
      "f(X) when X >= -N -> a.",           % unary minus on a variable in a guard
      "f(-N) -> a.",                       % unary minus on a variable as a pattern
      "f() -> -5."                          % expression
    ],
    [begin
       {ok, T, _} = erl_scan:string(S),
       {ok, F} = erl_parse:parse_form(T),
       Lint = case erl_lint:module([{attribute,1,module,m}, F]) of
                  {ok, W} -> {ok, length(W)};
                  {error, Es, _} -> {error, [E || {_, L} <- Es, E <- L]}
              end,
       io:format("~n~s~n  parse: ~0p~n  lint:  ~0p~n", [S, strip(F), Lint])
     end || S <- Forms],
    io:format("~npartial_eval (erl_lint's pattern-constant test, i.e. the CHECKER-side fold):~n"),
    [begin {ok,T,_} = erl_scan:string(S ++ "."), {ok,[E]} = erl_parse:parse_exprs(T),
           io:format("  ~-10s -> ~0p~n", [S, strip(erl_eval:partial_eval(E))]) end
     || S <- ["-5", "2+3", "-(2+3)*4", "- -5", "7 div 2", "-N"]],
    io:format("~nTYPE-attribute position (erl_parse:normalise/1, erl_parse.yrl:1984, folds - over a literal after the parse):~n"),
    [begin {ok,T,_} = erl_scan:string(S), {ok,F} = erl_parse:parse_form(T),
           io:format("  ~-34s parse: ~0p~n", [S, strip(F)]),
           io:format("  ~-34s lint:  ~0p~n", ["", case erl_lint:module([{attribute,1,module,m},F]) of {ok,_}->ok; {error,Es,_}->Es end]) end
     || S <- ["-type t() :: -5..5.", "-type t() :: -5..-1 | 1..5.", "-type t() :: 1..1."]].

strip(T) when is_tuple(T) ->
    case tuple_to_list(T) of
        [A, _Anno | R] when is_atom(A) -> list_to_tuple([A | [strip(X) || X <- R]]);
        L -> list_to_tuple([strip(X) || X <- L]) end;
strip(L) when is_list(L) -> [strip(X) || X <- L];
strip(X) -> X.
