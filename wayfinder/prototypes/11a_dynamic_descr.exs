# Ticket 11 — how two shipping BEAM checkers model `dynamic`, and what a fun's type is.
# Run: elixir 11a_dynamic_descr.exs   (observed on Elixir 1.19.5 / OTP 28)

alias Module.Types.Descr, as: D
IO.puts("=== elixir #{System.version()} / otp #{:erlang.system_info(:otp_release)} ===")

show = fn label, t -> IO.puts("#{label}\n    repr: #{inspect(t)}\n    to_quoted: #{Macro.to_string(D.to_quoted(t))}") end

show.("dynamic()", D.dynamic())
show.("term()", D.term())
show.("integer()", D.integer())
show.("dynamic(integer())", D.dynamic(D.integer()))

IO.puts("\n--- is dynamic a *type* in the algebra, or a mode? ---")
d_int = D.dynamic(D.integer())
show.("union(dynamic(integer), atom)", D.union(d_int, D.atom()))
show.("intersection(dynamic(), integer())", D.intersection(D.dynamic(), D.integer()))
show.("difference(dynamic(), integer())", D.difference(D.dynamic(), D.integer()))

IO.puts("\n--- the gradual guarantee: what is comparable to what? ---")
IO.puts("subtype?(integer, dynamic)        : #{inspect(D.subtype?(D.integer(), D.dynamic()))}")
IO.puts("subtype?(dynamic, integer)        : #{inspect(D.subtype?(D.dynamic(), D.integer()))}")
IO.puts("subtype?(dynamic, term)           : #{inspect(D.subtype?(D.dynamic(), D.term()))}")
IO.puts("compatible?(dynamic, integer)     : #{inspect(D.compatible?(D.dynamic(), D.integer()))}")
IO.puts("compatible?(dynamic(atom), integer): #{inspect(D.compatible?(D.dynamic(D.atom()), D.integer()))}")
IO.puts("compatible?(atom, integer)        : #{inspect(D.compatible?(D.atom(), D.integer()))}")
IO.puts("empty?(intersection(dyn(atom), integer)): #{inspect(D.empty?(D.intersection(D.dynamic(D.atom()), D.integer())))}")

IO.puts("
########## ARROWS ##########")
q = fn t -> Macro.to_string(D.to_quoted(t)) end

int_int  = D.fun([D.integer()], D.integer())
term_term= D.fun([D.term()], D.term())
none_term= D.fun([D.none()], D.term())

IO.puts("fun()            = #{q.(D.fun())}")
IO.puts("fn(int)->int     = #{q.(int_int)}")
IO.puts("fn(term)->term   = #{q.(term_term)}")
IO.puts("fn(none)->term   = #{q.(none_term)}")

IO.puts("\n--- contravariance: is fn(term)->term a SUBtype of fn(int)->int ? ---")
IO.puts("subtype?(fn(term)->term, fn(int)->int) : #{inspect(D.subtype?(term_term, int_int))}")
IO.puts("subtype?(fn(int)->int, fn(term)->term) : #{inspect(D.subtype?(int_int, term_term))}")

IO.puts("\n--- what is the TOP arrow (the one every fun inhabits)? ---")
for {name, t} <- [{"fun()", D.fun()}, {"fn(none)->term", none_term}, {"fn(term)->term", term_term}] do
  IO.puts("subtype?(fn(int)->int, #{name}) : #{inspect(D.subtype?(int_int, t))}")
end

IO.puts("\n--- so can you CALL the top arrow? what does it accept? ---")
IO.puts("subtype?(fun(), fn(term)->term)  : #{inspect(D.subtype?(D.fun(), term_term))}")
IO.puts("empty?(fn(none)->term)           : #{inspect(D.empty?(none_term))}")
