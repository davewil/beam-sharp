#!/usr/bin/env bash
# PROBE 60a -- ticket 60 (ENG-242). Claim under test:
#   C1. The BEAM enforces WHAT is callable (exported vs local) but has no notion of WHO calls.
#       Control: a local function IS refused across modules (undef) -- so the harness can go red.
#   C2. An exported function is callable from any module, including via apply/3 with a
#       module atom computed at run time and via a fun built with erlang:make_fun/3.
#   C3. A compile-time caller check sees direct calls and `fun M:F/A` (a distinct abstract form) but
#       NOT apply/3, computed atoms, or erlang:make_fun/3: those functions show zero edges.
# Run from anywhere. Needs erl/erlc on PATH.
set -uo pipefail
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$W"
cat > callee.erl <<'E'
-module(callee).
-export([exported/0]).
exported() -> {ok, helper()}.
helper() -> secret.
%% 'helper' is local; there is no way to say "exported, but only to caller_ok".
E
cat > caller_ok.erl <<'E'
-module(caller_ok).
-export([direct/0]).
direct() -> callee:exported().
E
cat > caller_bad.erl <<'E'
-module(caller_bad).
-export([direct/0, local_attempt/0, dynamic/1, dynamic_split/2, as_fun/0, as_make_fun/1]).
%% direct remote call: the form a compile-time checker CAN see
direct() -> callee:exported().
%% a local-only function across modules: the BEAM refuses
local_attempt() -> callee:helper().
%% apply/3 with a module atom that arrives at run time
dynamic(M) -> apply(M, exported, []).
%% module name assembled from pieces: no atom 'callee' appears in this module at all
dynamic_split(A, B) -> M = list_to_atom(A ++ B), M:exported().
%% fun value: external fun syntax
as_fun() -> F = fun callee:exported/0, F().
%% fun built by BIF from run-time atoms
as_make_fun(M) -> F = erlang:make_fun(M, exported, 0), F().
E
erlc +debug_info callee.erl caller_ok.erl caller_bad.erl || exit 2
cat > run.escript <<'E'
#!/usr/bin/env escript
main(_) ->

    R = fun(Label, F) -> V = (catch F()), V2 = case V of {'EXIT',{E,[{Mx,Fx,Ax,_}|_]}} -> {E,{Mx,Fx,Ax}}; _ -> V end, io:format("~-36s ~p~n", [Label, V2]) end,
    R("caller_ok:direct (authorised)",       fun() -> caller_ok:direct() end),
    R("caller_bad:direct (NOT authorised)",   fun() -> caller_bad:direct() end),
    R("CONTROL local-only across modules",    fun() -> caller_bad:local_attempt() end),
    R("apply(M,exported,[]) M=callee",        fun() -> caller_bad:dynamic(callee) end),
    R("list_to_atom(\"call\"++\"ee\")",       fun() -> caller_bad:dynamic_split("call","ee") end),
    R("fun callee:exported/0",                fun() -> caller_bad:as_fun() end),
    R("erlang:make_fun(M,exported,0)",        fun() -> caller_bad:as_make_fun(callee) end),
%% C3: what a form-reading checker sees in caller_bad
    {ok,{_,[{abstract_code,{_,AC}}]}} = beam_lib:chunks("caller_bad.beam",[abstract_code]),
    Remote = fun Walk(T) when is_tuple(T), element(1,T)==call, tuple_size(T)==4,
                          element(1,element(3,T))==remote ->
                 {remote,_,M,N} = element(3,T),
                 [{M,N}|lists:append([Walk(X)||X<-tuple_to_list(T)])];
             Walk({'fun',_,{function,{atom,_,M},{atom,_,N},_}}) -> [{{atom,0,M},{atom,0,N}}];  %% external fun IS a static edge (different form)
             Walk(T) when is_tuple(T) -> lists:append([Walk(X)||X<-tuple_to_list(T)]);
             Walk(L) when is_list(L)  -> lists:append([Walk(X)||X<-L]);
             Walk(_) -> [] end,
    Seen = [ {F, [N || {{atom,_,callee},{atom,_,N}} <- Remote(Body)]}
         || {function,_,F,_,Body} <- AC],
    io:format("~nstatic edges to callee a checker sees per function of caller_bad:~n"),
    [io:format("  ~-14s ~p~n",[F,L]) || {F,L} <- Seen],
ok.
E
escript run.escript
