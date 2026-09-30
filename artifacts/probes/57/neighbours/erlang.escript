#!/usr/bin/env escript
%% EXPECTED before run (Erlang/OTP 25, stdlib-4.3.1.3, compiler-8.2.6.3; sources NOT installed, behaviour probed):
%%  EL1 erl_parse of "-5." is {op,_,'-',{integer,_,5}}: the PARSER does not fold; unary minus is an operator node
%%  EL2 a pattern `f(-5) -> ok.` parses the head argument to the same {op,_,'-',{integer,_,5}}
%%  EL3 that module compiles and f(-5) = ok, f(5) function_clause
%%  EL4 `f(2+3) -> ok.` (arithmetic of literals in a PATTERN) compiles and f(5) = ok
%%  EL5 `g(X) when X >= 2+3 -> in; g(_) -> out.` compiles; g(4)=out, g(5)=in
%%  EL6 `f(2+X) -> ok.` is refused (a pattern may fold constants only): compile returns error
%%  EL7 the abstract format also accepts {integer,L,-5} (what parser fix A would emit): a module built from it compiles and f(-5)=ok
main(_) ->
    E1 = parse_expr("-5."),
    io:format("EL1 parse(\"-5.\") = ~p~n", [E1]),
    pass("EL1", match =:= (case E1 of {op,_,'-',{integer,_,5}} -> match; _ -> nomatch end)),
    {ok, [F2]} = {ok, [form("f(-5) -> ok.")]},
    io:format("EL2 head = ~p~n", [element(3, hd(element(5, F2)))]),
    pass("EL2", match =:= (case element(3, hd(element(5, F2))) of [{op,_,'-',{integer,_,5}}] -> match; _ -> nomatch end)),
    M3 = build("el3", ["f(-5) -> ok."]),
    pass("EL3", ok =:= M3:f(-5) andalso element(1, catch M3:f(5)) =:= 'EXIT'),
    M4 = build("el4", ["f(2+3) -> ok."]),
    pass("EL4", ok =:= M4:f(5)),
    M5 = build("el5", ["g(X) when X >= 2+3 -> in; g(_) -> out."]),
    pass("EL5", {out, in} =:= {M5:g(4), M5:g(5)}),
    R6 = build_result("el6", ["f(2+X) -> ok."]),
    io:format("EL6 compile result = ~p~n", [element(1, R6)]),
    pass("EL6", error =:= element(1, R6)),
    Forms7 = [{attribute,1,module,el7}, {attribute,1,export,[{f,1}]},
              {function,1,f,1,[{clause,1,[{integer,1,-5}],[],[{atom,1,ok}]}]}],
    {ok, el7, Bin7} = compile:forms(Forms7),
    {module, el7} = code:load_binary(el7, "el7", Bin7),
    pass("EL7", ok =:= el7:f(-5)).
pass(N, true) -> io:format("PASS ~s~n", [N]);
pass(N, _) -> io:format("FAIL ~s~n", [N]).
toks(S) -> {ok, T, _} = erl_scan:string(S), T.
parse_expr(S) -> {ok, [E]} = erl_parse:parse_exprs(toks(S)), E.
form(S) -> {ok, F} = erl_parse:parse_form(toks(S)), F.
forms(Name, Bodies) ->
    [{attribute,1,module,list_to_atom(Name)}]
      ++ [form(B) || B <- Bodies].
build_result(Name, Bodies) -> compile:forms(forms(Name, Bodies), [return_errors, export_all, nowarn_export_all]).
build(Name, Bodies) ->
    {ok, Mod, Bin} = compile:forms(forms(Name, Bodies), [export_all, nowarn_export_all]),
    {module, Mod} = code:load_binary(Mod, Name, Bin), Mod.
