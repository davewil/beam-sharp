#!/bin/bash
# Ticket 52 (ENG-234): what does a .bs file say about the application it needs?
. "$(dirname "$0")/../env.sh"
work 52
mkdir R
cat > R/R.bs <<'B'
module R
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
public term Client()
Client() -> :'Elixir.Req'.new([])
B
echo "### P1 baseline: the dependency is absent (no ERL_LIBS) — does bsc say anything at compile time?"
bsc --src-root . -o . R 2>&1 | head -3; echo "compile exit=$?   beam written: $(ls R.beam 2>/dev/null || echo no)"
echo "### P2 ...and at run time"
bsc --src-root . R Client 2>&1 | head -3
echo "### P3 does the .beam or .abstr record any application? (grep for req)"
grep -c -i "req" R.abstr; erl -noshell -eval '{ok,{_,[{attributes,A}]}}=beam_lib:chunks("R.beam",[attributes]), io:format("beam attributes: ~p~n",[A]), halt().'

echo; echo "### P4 what the VM itself can answer at compile time, and what each answer costs (mean of 20000 calls)"
cat > p4.escript <<'B'
#!/usr/bin/env escript
main(_) ->
    Req = 'Elixir.Req',
    Tm = fun(L, F) -> {U, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, 20000)] end),
                      io:format("  ~-44s ~.2f us~n", [L, U / 20000]) end,
    io:format("  code:which(lists)        -> ~p~n", [code:which(lists)]),
    io:format("  code:which('Elixir.Req') -> ~p~n", [code:which(Req)]),
    io:format("  code:lib_dir(stdlib)     -> ~p~n", [code:lib_dir(stdlib)]),
    io:format("  code:lib_dir(req)        -> ~p~n", [code:lib_dir(req)]),
    Tm("code:which(Module), loaded", fun() -> code:which(lists) end),
    Tm("code:which(Module), absent (scans path)", fun() -> code:which(Req) end),
    Tm("code:lib_dir(App), present", fun() -> code:lib_dir(stdlib) end),
    Tm("code:lib_dir(App), absent", fun() -> code:lib_dir(req) end).
B
escript p4.escript

echo; echo "### P5 module -> application is derivable from where the module was found (no declaration needed)"
cat > p5.escript <<'B'
#!/usr/bin/env escript
main(_) ->
    App = fun(M) -> case code:which(M) of
                  non_existing -> {M, absent};
                  P -> N = filename:basename(filename:dirname(filename:dirname(P))),
                       {M, hd(string:split(N, "-"))} end end,
    io:format("  ~p~n  ~p~n", [App(lists), App('Elixir.Req')]).
B
escript p5.escript
echo "### P6 an Elixir module is only found if Elixir's lib dir is on the path:"
elixir -e 'IO.inspect(:code.which(Logger) |> to_string |> Path.dirname |> Path.dirname |> Path.basename, label: "  Logger lives in app dir")' 2>&1 | grep -v warning
erl -noshell -eval 'io:format("  without elixir on the path: code:which(Elixir.Logger) -> ~p~n", [code:which(list_to_atom("Elixir.Logger"))]), halt().'

echo; echo "### Gleam: external to a missing module — compile-time check?"
mkdir -p g/src && cd g && printf 'name = "g"\nversion = "1.0.0"\n' > gleam.toml
cat > src/g.gleam <<'B'
@external(erlang, "Elixir.Req", "new")
pub fn new(opts: List(a)) -> b
pub fn main() { new([]) }
B
gleam build --target erlang 2>&1 | tail -2
cd ..
echo; echo "### Elixir: call into a module that is not available — compile-time?"
cat > m.ex <<'B'
defmodule M do
  def go, do: Req.new([])
end
B
elixirc --no-docs -o . m.ex 2>&1 | grep -v 'warning: the VM' | head -6
echo; echo "### Erlang: erlc on a call to an absent module"
cat > e.erl <<'B'
-module(e).
-export([go/0]).
go() -> 'Elixir.Req':new([]).
B
mkdir xd && erlc +debug_info -o xd e.erl && echo "erlc: compiled silently (exit $?)"
erlc +warn_missing_spec e.erl 2>&1 | head -2
echo "--- erlang's xref does the check, outside the compiler:"
cat > x.escript <<'B'
#!/usr/bin/env escript
main(_) ->
    {ok, _} = xref:start(s), xref:set_default(s, [{warnings, false}]),
    {ok, _} = xref:add_directory(s, "xd"),
    {ok, U} = xref:analyze(s, undefined_function_calls),
    io:format("  xref undefined_function_calls: ~p~n", [U]).
B
escript x.escript 2>&1 | head -4
