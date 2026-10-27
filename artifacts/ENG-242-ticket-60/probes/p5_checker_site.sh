#!/usr/bin/env bash
# Model of the ticket-60 delta at the REAL add_module_import/5 site, in a scratch copy of compiler/src/bs_check.erl
# (compiled on OTP 25 with +export_all; the repo pins OTP 28.5; NOT the shipped bsc, which cannot be built here).
# Hypotheses (falsifiable):
#  H1 unpatched copy accepts an import of a module regardless of who imports it (control: accepted/accepted).
#  H2 direction A (callee entry carries visible_to prefixes, checked in add_import with Self) rejects the
#     outsider and accepts the insider (expect: rejected for Other.X, accepted for Shop.Orders.Total).
#  H3 direction B (caller's own `may_use` list, checked per import) rejects an import outside its list.
#  H4 per-import cost is O(1) in N (World size); report ns/import for N=100,1000,10000. No threshold tuned.
set -e
S=${SCRATCH:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/chk}
SRC=/home/user/beam-sharp/compiler/src/bs_check.erl
rm -rf "$S" && mkdir -p "$S" && cd "$S"
erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'
cp "$SRC" bs_check.erl
python3 -I - <<'PY'
import re
src=open('bs_check.erl').read()
assert src.count("add_module_import(M, World, Acc) ->\n    Entry = maps:get(M, World),")==1
assert src.count("true  -> add_module_import(M, World, Acc);")==1
# Direction A: callee declares who may name it
a=src.replace("-module(bs_check).","-module(bs_check_a).")
a=a.replace("true  -> add_module_import(M, World, Acc);",
 "true  -> visible_to(M, Self, L, World), add_module_import(M, World, Acc);")
a+='''
visible_to(M, Self, L, World) ->
    case maps:get(visible_to, maps:get(M, World), any) of
        any -> ok;
        Prefixes ->
            S = atom_to_list(Self) ++ ".",
            case lists:any(fun(P) -> lists:prefix(atom_to_list(P) ++ ".", S) end, Prefixes) of
                true -> ok;
                false -> erlang:error({not_visible_to, M, Self, L})
            end
    end.
'''
open('bs_check_a.erl','w').write(a)
# Direction B: caller declares what it may use (list carried in World entry of Self under may_use)
b=src.replace("-module(bs_check).","-module(bs_check_b).")
b=b.replace("true  -> add_module_import(M, World, Acc);",
 "true  -> may_use(M, Self, L, World), add_module_import(M, World, Acc);")
b+='''
may_use(M, Self, L, World) ->
    case maps:get(may_use, maps:get(Self, World, #{}), any) of
        any -> ok;
        Prefixes ->
            S = atom_to_list(M) ++ ".",
            case lists:any(fun(P) -> lists:prefix(atom_to_list(P) ++ ".", S) end, Prefixes) of
                true -> ok;
                false -> erlang:error({not_in_may_use, M, Self, L})
            end
    end.
'''
open('bs_check_b.erl','w').write(b)
PY
erlc +export_all +nowarn_export_all +nowarn_unused_function bs_check.erl bs_check_a.erl bs_check_b.erl
cat > run.erl <<'X'
-module(run).
-export([main/0]).
entry(Extra) -> maps:merge(#{exports => #{{'F',1} => sig}, types => #{}}, Extra).
world(N, Extra) ->
    Base = #{'Shop.Orders' => entry(Extra), 'Shop.Orders.Total' => entry(#{}),
             'Other.X' => entry(#{}), 'Shop.Reports' => entry(#{})},
    lists:foldl(fun(I, W) -> W#{list_to_atom("Pad.M" ++ integer_to_list(I)) => entry(#{})} end, Base, lists:seq(1, N)).
try_imp(Mod, Self, World, Target) ->
    try Mod:import_env([{import, 1, Target}], Self, World, strict), accepted
    catch error:E -> {rejected, E} end.
main() ->
    W0 = world(10, #{}),
    io:format("H1 unpatched: insider ~p / outsider ~p~n",
      [try_imp(bs_check,'Shop.Orders.Total',W0,'Shop.Orders'), try_imp(bs_check,'Other.X',W0,'Shop.Orders')]),
    WA = world(10, #{visible_to => ['Shop.Orders']}),
    io:format("H2 dir A: insider ~p / outsider ~p~n",
      [try_imp(bs_check_a,'Shop.Orders.Total',WA,'Shop.Orders'), try_imp(bs_check_a,'Other.X',WA,'Shop.Orders')]),
    WB0 = world(10, #{}),
    WB = WB0#{'Other.X' := (maps:get('Other.X',WB0))#{may_use => ['Shop.Reports']}},
    io:format("H3 dir B: Other.X may_use [Shop.Reports]: import Shop.Reports ~p / import Shop.Orders ~p~n",
      [try_imp(bs_check_b,'Other.X',WB,'Shop.Reports'), try_imp(bs_check_b,'Other.X',WB,'Shop.Orders')]),
    io:format("H4 cost: one import_env of 10 imports, mean over 2000 reps (ns per import)~n"),
    lists:foreach(fun(N) ->
        Wp = world(N, #{}), WpA = world(N, #{visible_to => ['Shop.Orders']}),
        Imps = [{import,1,'Shop.Orders'} || _ <- lists:seq(1,10)],
        T = fun(Mod, W, Self) -> {US,_} = timer:tc(fun() -> [Mod:import_env(Imps, Self, W, strict) || _ <- lists:seq(1,2000)] end), US*1000/(2000*10) end,
        T(bs_check, Wp, 'Other.X'),
        io:format("  N=~w  base ~.1f   dirA ~.1f   (insider)~n", [N, T(bs_check,Wp,'Shop.Orders.Total'), T(bs_check_a,WpA,'Shop.Orders.Total')])
    end, [100, 1000, 10000]).
X
erlc run.erl && erl -noshell -pa . -eval 'run:main(), halt().'
