# Deterministic derivation candidates over B#-legal function names ([A-Z][A-Za-z0-9_]*, bs_lexer.xrl:14-16,150).
# E = Elixir's own Macro.underscore (what an Elixir caller would write); G = Gleam's per-capital rule,
# reimplemented here and ASSERTED against what the gleam binary emitted (04_gleam_names.out); L = lowercase first letter only.
g = fn s -> s |> String.graphemes() |> Enum.with_index()
         |> Enum.map(fn {c, i} -> if c =~ ~r/[A-Z]/, do: (if i == 0, do: String.downcase(c), else: "_" <> String.downcase(c)), else: c end)
         |> Enum.join() end
e = &Macro.underscore/1
l = fn <<c::utf8, r::binary>> -> String.downcase(<<c::utf8>>) <> r end

# Gleam's real output, copied from 04_gleam_names.out (variant name -> atom)
gleam_actual = %{"Order"=>"order","HTTPGet"=>"h_t_t_p_get","ToJSON"=>"to_j_s_o_n","New2"=>"new2","FooBar"=>"foo_bar",
  "Foobar"=>"foobar","ABC"=>"a_b_c","Abc"=>"abc","A1B"=>"a1_b","XMLHttpRequest2"=>"x_m_l_http_request2",
  "IOError"=>"i_o_error","Get"=>"get","Get2"=>"get2"}
for {k, v} <- gleam_actual, do: (g.(k) == v or raise "G does not match gleam for #{k}: #{g.(k)} vs #{v}")
IO.puts("G reimplementation == gleam binary output on all #{map_size(gleam_actual)} names: OK\n")

names = ~w(New Which HTTPGet ToJSON New2 FooBar Foobar ABC Abc A1B XMLHttpRequest2 IOError Get2 Get_2 Foo_Bar Foo_bar
           Foo__Bar GetX Get_X Parse2Json ParseJSON2 X URL Init HandleCall _X)
IO.puts(String.pad_trailing("B# name", 18) <> String.pad_trailing("E Macro.underscore", 22) <> String.pad_trailing("G gleam-style", 22) <> "L first-letter")
for n <- names, n =~ ~r/^[A-Z]/ do
  IO.puts(String.pad_trailing(n, 18) <> String.pad_trailing(e.(n), 22) <> String.pad_trailing(g.(n), 22) <> l.(n))
end

IO.puts("\nCollisions inside one module (two B# names -> one alias atom):")
for {nm, f} <- [E: e, G: g, L: l] do
  groups = names |> Enum.filter(&(&1 =~ ~r/^[A-Z]/)) |> Enum.group_by(f) |> Enum.filter(fn {_, v} -> length(v) > 1 end)
  IO.puts("  #{nm}: " <> inspect(groups))
end
IO.puts("\nAlias equals an atom the module already exports under the callback table (bs_otp.erl:40ff):")
IO.puts("  Init -> E:#{e.("Init")} G:#{g.("Init")}; HandleCall -> E:#{e.("HandleCall")} G:#{g.("HandleCall")} (emitted already as init/handle_call)")
