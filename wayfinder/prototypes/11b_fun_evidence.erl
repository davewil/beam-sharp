-module(run).
-export([main/0]).
try_call(Label, F) ->
    try io:format("  ~-28s -> ~p~n", [Label, F()])
    catch C:R -> io:format("  ~-28s -> ** ~p:~p **~n", [Label, C, R]) end.
main() ->
    {ok, hotmod, B1} = compile:file("v1.erl", [binary, {outdir,"."}]),
    {module, hotmod} = code:load_binary(hotmod, "hotmod.beam", B1),
    Closure = hotmod:make_closure(),
    External = hotmod:make_external(),
    Mfa = {hotmod, f, 1},
    io:format("~n== before upgrade (v1 loaded) ==~n"),
    try_call("local closure", fun() -> Closure(1) end),
    try_call("external fun  fun M:F/1", fun() -> External(1) end),
    try_call("MFA  apply(M,F,A)", fun() -> {M,F,A}=Mfa, erlang:apply(M,F,[1]) end),
    {ok, hotmod, B2} = compile:file("v2.erl", [binary, {outdir,"."}]),
    {module, hotmod} = code:load_binary(hotmod, "hotmod.beam", B2),
    io:format("~n== after loading v2 (v1 now 'old' code) ==~n"),
    try_call("local closure", fun() -> Closure(1) end),
    try_call("external fun  fun M:F/1", fun() -> External(1) end),
    try_call("MFA  apply(M,F,A)", fun() -> {M,F,A}=Mfa, erlang:apply(M,F,[1]) end),
    code:purge(hotmod),
    {ok, hotmod, B3} = compile:file("v2.erl", [binary, {outdir,"."}]),
    {module, hotmod} = code:load_binary(hotmod, "hotmod.beam", B3),
    code:purge(hotmod),
    io:format("~n== after purge (v1 code gone) ==~n"),
    try_call("local closure", fun() -> Closure(1) end),
    try_call("external fun  fun M:F/1", fun() -> External(1) end),
    try_call("MFA  apply(M,F,A)", fun() -> {M,F,A}=Mfa, erlang:apply(M,F,[1]) end),
    io:format("~n== what evidence does a fun carry? ==~n"),
    io:format("  erlang:fun_info(External): ~p~n", [[ {K,V} || {K,V} <- erlang:fun_info(External), lists:member(K,[module,name,arity,type])]]),
    io:format("  erlang:fun_info(Closure) : ~p~n", [[ {K,V} || {K,V} <- erlang:fun_info(Closure), lists:member(K,[module,name,arity,type])]]),
    io:format("  is_function(Closure, 1)  : ~p~n", [is_function(Closure, 1)]),
    halt(0).
