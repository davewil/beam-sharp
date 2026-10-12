#!/usr/bin/env bash
# 57-06 AST shape of `-5` and `2+3` in Erlang and Elixir, and where each folds.
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT; cd "$work"
echo "== Erlang: erl_parse output (parser does NOT fold) =="
cat > shape.escript <<'EOS'
#!/usr/bin/env escript
main(_) ->
    P = fun(S) -> {ok,T,_} = erl_scan:string(S), {ok,[E]} = erl_parse:parse_exprs(T),
                  io:format("~-10s ~p~n",[S,E]) end,
    lists:foreach(P, ["-5.", "2+3.", "- -5.", "X >= -5.", "-5.0."]),
    io:format("erl_eval:partial_eval -5  -> ~p~n",[erl_eval:partial_eval({op,1,'-',{integer,1,5}})]),
    io:format("erl_eval:partial_eval 2+3 -> ~p~n",[erl_eval:partial_eval({op,1,'+',{integer,1,2},{integer,1,3}})]),
    io:format("erl_eval:partial_eval X+3 -> ~p~n",[erl_eval:partial_eval({op,1,'+',{var,1,'X'},{integer,1,3}})]).
EOS
escript shape.escript
echo "== Erlang: a PATTERN with constant arithmetic is accepted and folded by the compiler (v3_core -> erl_eval:partial_eval) =="
cat > pat.erl <<'EOS'
-module(pat).
-export([f/1, g/1]).
-type r() :: -5..5.
-type r2() :: (1+1)..5.
-spec f(integer()) -> atom().
f(-1) -> neg1;
f(2+3) -> five;
f(_) -> other.
g(X) when X >= -5, X =< 2*3 -> in;
g(_) -> out.
EOS
erlc +debug_info pat.erl && erl -noshell -eval 'io:format("f(5)=~p f(-1)=~p g(-5)=~p g(6)=~p g(7)=~p~n",[pat:f(5),pat:f(-1),pat:g(-5),pat:g(6),pat:g(7)]),halt().'
echo "== Erlang: abstract code after lint, pattern f(2+3) =="
erl -noshell -eval '{ok,{_,[{abstract_code,{_,AC}}]}}=beam_lib:chunks("pat.beam",[abstract_code]), [io:format("~p~n",[C]) || {function,_,f,_,[_,C|_]} <- AC], halt().'
echo "== Elixir: quoted forms (parser does NOT fold) =="
elixir -e '
for s <- ["-5", "2+3", "- -5", "x >= -5", "-5.0", "-(5)", "-5..5", "1+1..5"] do
  IO.puts(String.pad_trailing(s, 10) <> inspect(Code.string_to_quoted!(s), limit: :infinity))
end
defmodule P do
  def f(-1), do: :neg1
  def f(x) when x >= -5 and x <= 2*3, do: :in
  def f(_), do: :out
end
IO.inspect({P.f(-1), P.f(-5), P.f(6), P.f(7)}, label: "f(-1),f(-5),f(6),f(7)")
IO.puts("-- Elixir pattern with arithmetic:")
try do
  Code.eval_string("defmodule Q do\n def f(2+3), do: 1\nend")
rescue e -> IO.puts(Exception.message(e) |> String.split("\n") |> hd)
end
'
