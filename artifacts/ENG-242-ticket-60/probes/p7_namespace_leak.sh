#!/usr/bin/env bash
# Needs p5 first (scratch dir with bs_check.erl copy). Hypothesis H1 (a soundness hole in the naive patch):
# guarding only add_module_import lets an OUTSIDER reach a restricted module through a NAMESPACE import
# (`using Shop` imports every child, via add_namespace_import, never reaching the guarded branch).
# Falsifiable: expect outsider `using Shop` to be ACCEPTED and to list 'Shop.Orders' in `imported` (the leak).
# H2: filtering children by visibility in add_namespace_import closes it: outsider's imported list then omits
# 'Shop.Orders' while the insider still gets it.
S=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/chk
cd "$S" || exit 2
python3 -I - <<'PY'
src=open('bs_check_a.erl').read()
c=src.replace("-module(bs_check_a).","-module(bs_check_c).")
old="{Children, _} -> add_namespace_import(M, Children, Acc)"
assert src.count(old)==1
c=c.replace(old,"{Children, _} -> add_namespace_import(M, [C || C <- Children, visible_p(C, Self, World)], Acc)")
c+='''
visible_p(M, Self, World) ->
    try visible_to(M, Self, 0, World), true catch error:{not_visible_to,_,_,_} -> false end.
'''
open('bs_check_c.erl','w').write(c)
PY
erlc +export_all +nowarn_export_all +nowarn_unused_function bs_check_c.erl
cat > leak.erl <<'X'
-module(leak).
-export([main/0]).
e(Extra) -> maps:merge(#{exports => #{{'F',1} => sig}, types => #{}}, Extra).
main() ->
  W = #{'Shop.Orders' => e(#{visible_to => ['Shop.Orders']}), 'Shop.Reports' => e(#{}), 'Other.X' => e(#{})},
  Imp = [{import,1,'Shop'}],
  R = fun(Mod, Self) -> try maps:get(imported, Mod:import_env(Imp, Self, W, strict)) catch error:E -> {err,E} end end,
  io:format("H1 naive patch (module-branch only): outsider using Shop -> ~p~n", [lists:sort(R(bs_check_a,'Other.X'))]),
  io:format("H2 children filtered: outsider -> ~p ; insider 'Shop.Orders.Total' -> ~p~n",
            [lists:sort(R(bs_check_c,'Other.X')), lists:sort(R(bs_check_c,'Shop.Orders.Total'))]).
X
erlc leak.erl && erl -noshell -pa . -eval 'leak:main(),halt().'
