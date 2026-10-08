#!/usr/bin/env bash
# Probe 5: how do existing BEAM languages/tooling name and expose exports; what does Elixir tooling do with non-snake atoms.
. "$(dirname "$0")/common.sh"
echo "### A. Elixir stdlib export-name shapes (Enum, String, Map, Kernel): how ? ! and operators appear as atoms ###"
cat > $SCR/p5a.exs <<'EXS'
for m <- [Enum, String, Map, Kernel, Keyword, List] do
  ex = m.module_info(:exports) |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
  s = Enum.map(ex, &Atom.to_string/1)
  IO.puts("#{inspect m}: #{length(s)} distinct names; ends-?: #{Enum.count(s, &String.ends_with?(&1, "?"))}; ends-!: #{Enum.count(s, &String.ends_with?(&1, "!"))}; non [a-z_]-initial: #{Enum.count(s, &(not String.match?(&1, ~r/^[a-z_]/)))}; uppercase-initial: #{Enum.count(s, &String.match?(&1, ~r/^[A-Z]/))}")
end
IO.inspect(Enum.module_info(:exports) |> Enum.map(&elem(&1,0)) |> Enum.filter(&(Atom.to_string(&1) =~ ~r/[?!]$/)) |> Enum.uniq() |> Enum.take(6), label: "sample ?/! exports as raw atoms")
IO.inspect(Kernel.module_info(:exports) |> Enum.map(&elem(&1,0)) |> Enum.reject(&(Atom.to_string(&1) =~ ~r/^[a-z_]/)) |> Enum.uniq() |> Enum.take(12), label: "Kernel non-letter-initial exports (operators)")
EXS
elixir $SCR/p5a.exs 2>&1
echo
echo "### B. Erlang/OTP 25: exports (all .beam under /usr/lib/erlang/lib/*/ebin) whose name is NOT lowercase-letter-initial or contains uppercase ###"
cat > $SCR/p5b.erl <<'ERL'
-module(p5b).
-export([main/0]).
main() ->
    Beams = filelib:wildcard("/usr/lib/erlang/lib/*/ebin/*.beam"),
    {N, Tot, Odd, Upper, Mods} = lists:foldl(fun(B, {Ms, T, O, U, Md}) ->
        case beam_lib:chunks(B, [exports]) of
            {ok, {M, [{exports, E}]}} ->
                Names = [X || {X, _} <- E, X =/= module_info],
                Odd1 = [{M, X} || X <- Names, not is_lower_init(atom_to_list(X))],
                Up1 = [{M, X} || X <- Names, lists:any(fun(C) -> C >= $A andalso C =< $Z end, atom_to_list(X))],
                {Ms + 1, T + length(Names), O ++ Odd1, U ++ Up1, [M | Md]};
            _ -> {Ms, T, O, U, Md}
        end end, {0, 0, [], [], []}, Beams),
    io:format("beams read: ~p, total exported function names: ~p~n", [N, Tot]),
    io:format("exports not lowercase-letter-initial: ~p (~p modules)~n", [length(Odd), length(lists:usort([M || {M, _} <- Odd]))]),
    io:format("  sample: ~p~n", [lists:sublist(Odd, 20)]),
    io:format("exports containing any uppercase letter: ~p (~p modules)~n", [length(Upper), length(lists:usort([M || {M, _} <- Upper]))]),
    io:format("  sample: ~p~n", [lists:sublist(Upper, 25)]),
    NonWx = [{M, X} || {M, X} <- Upper, not lists:prefix("wx", atom_to_list(M))],
    io:format("  ...excluding wx* modules: ~p exports in ~p modules; modules: ~p~n", [length(NonWx), length(lists:usort([M || {M, _} <- NonWx])), lists:usort([M || {M, _} <- NonWx])]),
    io:format("uppercase-INITIAL exports: ~p~n", [[{M, X} || {M, X} <- Upper, hd(atom_to_list(X)) >= $A, hd(atom_to_list(X)) =< $Z]]),
    %% control: the scan must be able to find a non-lowercase export, so test it on a known-odd module we build
    ok = file:write_file("/tmp/ctl_odd.erl", "-module(ctl_odd). -export(['New'/1, '_x'/0]). 'New'(X) -> X. '_x'() -> 1."),
    {ok, ctl_odd, Bin} = compile:file("/tmp/ctl_odd.erl", [binary]),
    {ok, {_, [{exports, CE}]}} = beam_lib:chunks(Bin, [exports]),
    io:format("CONTROL (must list 'New' and '_x'): ~p~n", [[X || {X, _} <- CE, not is_lower_init(atom_to_list(X)), X =/= module_info]]),
    Mods.
is_lower_init([C|_]) -> C >= $a andalso C =< $z;
is_lower_init([]) -> false.
ERL
(cd $SCR && erlc p5b.erl) && erl -noshell -pa $SCR -eval 'p5b:main(), halt().' 2>&1
echo
echo "### C. Elixir tooling on a non-snake export atom (1.14.0) ###"
cat > $SCR/p5c.exs <<'EXS'
IO.puts(Code.format_string!(~S|:Shop."New"(1)|) |> IO.iodata_to_binary())
IO.puts(Code.format_string!(~S|:shop."new"(1)|) |> IO.iodata_to_binary())
IO.puts(Code.format_string!(~S{:Shop."Which"(x) |> :Shop."Amount"()}) |> IO.iodata_to_binary())
IO.inspect(Macro.inspect_atom(:literal, :New), label: "inspect_atom :New")
IO.inspect(:New, label: "inspect :New")
IO.inspect(Macro.to_string(quote do: :Shop."New"(1)), label: "Macro.to_string of quoted call")
IO.inspect(Code.Fragment.surround_context(":Shop.New(1)", {1, 8}), label: "surround_context :Shop.New")
IO.inspect(IEx.Autocomplete.expand(~c":Shop.Ne"), label: "IEx autocomplete :Shop.Ne") 
EXS
elixir $SCR/p5c.exs 2>&1 | grep -v '^warning'
echo
echo "### D. Elixir compiler warnings when calling the quoted-name form from a compiled module ###"
cat > $SCR/p5d.exs <<'EXS'
Code.prepend_path(System.get_env("EB"))
Code.put_compiler_option(:warnings_as_errors, false)
Code.compile_string(~S|defmodule Caller do
  def go, do: :Shop."New"(1)
end|)
IO.inspect(Caller.go(), label: "Caller.go()")
EXS
build_shop $SCR/p5ebin >/dev/null; EB=$SCR/p5ebin elixir $SCR/p5d.exs 2>&1 | head -8
