#!/usr/bin/env bash
# Ticket 57 survey: where do the BEAM neighbours fold `-5`: tokenizer/parser, or a later constant-folding pass?
# Elixir and Gleam ship without sources in this sandbox, so those two are measured by behaviour, not cited by line.
export PATH=/tmp/tools:$PATH
W=$(mktemp -d); cd "$W"
echo "== Erlang: what does the parser hand the compiler for  -5  in a guard and in a pattern?"
erl -noshell -eval '
  {ok,T,_} = erl_scan:string("f(X) when X >= -5 -> X."), {ok,F} = erl_parse:parse_form(T),
  {function,_,f,1,[{clause,_,_,[[G]],_}]} = F, io:format("guard AST      : ~p~n",[G]),
  {ok,T2,_} = erl_scan:string("f(-5) -> a."), {ok,F2} = erl_parse:parse_form(T2),
  {function,_,f,1,[{clause,_,[P],_,_}]} = F2, io:format("pattern AST    : ~p~n",[P]),
  {ok,T3,_} = erl_scan:string("f(X) when X >= 2 + 3 -> X."), {ok,F3} = erl_parse:parse_form(T3),
  {function,_,f,1,[{clause,_,_,[[G3]],_}]} = F3, io:format("2 + 3 AST     : ~p~n",[G3]), halt().'
echo "   -> the parser leaves {op,_,\"-\",{integer,_,5}} unfolded in BOTH positions; folding is a later pass."
echo "== Erlang: where is the fold? (OTP 27 source in the sandbox)"
S=/tmp/tools/otp_src_27.3.4/lib
grep -n "eval_op\|fold_lit\|negative integer literal" $S/stdlib/src/erl_parse.yrl | head -5
grep -n "^partial_eval(\|partial_eval(\[" $S/stdlib/src/erl_lint.erl | head -3
grep -n "'-', *{integer\|{op,.*'-'.*{integer" $S/stdlib/src/erl_parse.yrl $S/compiler/src/sys_core_fold.erl $S/compiler/src/v3_core.erl 2>/dev/null | head -8
echo "== Elixir: AST of -5 (guard comparand), and does a 2+3 comparand compile in a guard?"
elixir -e 'IO.inspect(quote do: x >= -5); defmodule G do def f(x) when x >= -5, do: :a; def f(_), do: :b; def g(x) when x >= 2 + 3, do: :a; def g(_), do: :b end; IO.inspect({G.f(-5), G.f(-6), G.g(5), G.g(4)})'
echo "== Gleam: a guard with a negative literal, and a negative literal pattern"
mkdir -p g/src && cd g && printf 'name = "g"\nversion = "1.0.0"\ntarget = "erlang"\n' > gleam.toml
cat > src/g.gleam <<'EOF'
pub fn f(x: Int) -> Int {
  case x {
    -5 -> 1
    n if n >= -5 -> 2
    n if n >= 2 + 3 -> 3
    _ -> 4
  }
}
EOF
gleam build 2>&1 | tail -3
