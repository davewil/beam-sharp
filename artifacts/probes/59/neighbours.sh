#!/bin/bash
# Ticket 59: what do Gleam, Elixir and Erlang do about a forged value reaching a public vs a private function?
. "$(dirname "$0")/../env.sh"
work 59n
echo "### Gleam: public and private function over a record; call each with a forged tuple of the same arity"
mkdir -p g/src && cd g && printf 'name = "g"\nversion = "1.0.0"\n' > gleam.toml
cat > src/g.gleam <<'B'
pub type Order { Order(id: Int, total: Int) }
pub fn pub_total(o: Order) -> Int { o.total }
fn priv_total(o: Order) -> Int { o.total }
pub fn via_priv(os: List(Order)) -> Int {
  case os { [o, ..] -> priv_total(o) [] -> 0 }
}
pub fn pub_double(x: Int) -> Int { x * 2 }
B
gleam build --target erlang 2>&1 | tail -1
erl -noshell -pa build/dev/erlang/g/ebin -eval '
T=fun(L,F)-> R=try F() of V->{returned,V} catch C:E->{C,E} end, io:format("  ~-34s ~p~n",[L,R]) end,
T("pub_total({other,1,77})", fun()-> g:pub_total({other,1,77}) end),
T("via_priv([{other,1,77}])", fun()-> g:via_priv([{other,1,77}]) end),
T("pub_double(2.5)", fun()-> g:pub_double(2.5) end),
{beam_file,_,_,_,_,Is}=beam_disasm:file("build/dev/erlang/g/ebin/g.beam"),
[io:format("  ~p: ~p type-test instructions~n",[N,length([x||{test,Op,_,_}<-C, lists:member(Op,[is_integer,is_tuple,test_arity,is_eq_exact])])]) || {function,N,_,_,C} <- Is, lists:member(N,[pub_total,priv_total,pub_double])],
halt().' 2>&1
cd ..
echo "### Elixir: struct pattern in def vs defp — the match is in the head either way"
cat > m.ex <<'B'
defmodule O do
  defstruct [:id, :total]
end
defmodule M do
  def pub(%O{} = o), do: o.total
  def via_priv(os), do: priv(hd(os))
  defp priv(%O{} = o), do: o.total
  def pub_untyped(o), do: priv2(o)
  defp priv2(o), do: o.total
end
B
elixirc --no-docs -o . m.ex 2>&1 | grep -v warning
elixir -e '
t = fn l, f -> r = try do {:returned, f.()} rescue e -> {:error, e.__struct__} end; IO.puts("  #{String.pad_trailing(l, 40)} #{inspect(r)}") end
forged = %{__struct__: Other, id: 1, total: 77}
t.("pub(forged struct)", fn -> M.pub(forged) end)
t.("via_priv([forged struct])  (defp %O{} head)", fn -> M.via_priv([forged]) end)
t.("pub_untyped(forged)        (no head match)", fn -> M.pub_untyped(forged) end)' 2>&1 | grep -v warning
