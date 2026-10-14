#!/bin/bash
# escape59.sh VARIANT... : a private function handed out as a fn value, then called from plain Erlang with a wrong-record map and a float
for v in "$@"; do
  echo "######## $v"; rm -rf out_${v}_E; mkdir -p out_${v}_E
  ./$v/bsc.sh --src-root p59d -o out_${v}_E p59d/E </dev/null 2>&1 | head -3
  erl -noshell -pa out_${v}_E -eval '
    H = '"'"'E'"'"':'"'"'Handler'"'"'(), C = '"'"'E'"'"':'"'"'Classifier'"'"'(),
    T = fun(Label, F) -> R = try F() catch Cl:Rs -> {Cl,Rs} end, io:format("~-58s ~p~n",[Label, R]) end,
    T("Handler()(Order map)",                       fun() -> H(#{'"'"'Kind'"'"'=>'"'"'E.Order'"'"','"'"'Id'"'"'=>1,'"'"'Total'"'"'=>7}) end),
    T("Handler()(Invoice map, same fields: wrong record)", fun() -> H(#{'"'"'Kind'"'"'=>'"'"'E.Invoice'"'"','"'"'Id'"'"'=>1,'"'"'Total'"'"'=>7}) end),
    T("Classifier()(100)",                          fun() -> C(100) end),
    T("Classifier()(8.5)  [float into a private int fn]", fun() -> C(8.5) end),
    T("Classifier()(9.5)",                          fun() -> C(9.5) end),
    T("Direct(Invoice map) [exported entry]",       fun() -> '"'"'E'"'"':'"'"'Direct'"'"'(#{'"'"'Kind'"'"'=>'"'"'E.Invoice'"'"','"'"'Id'"'"'=>1,'"'"'Total'"'"'=>7}) end),
    halt().'
done
