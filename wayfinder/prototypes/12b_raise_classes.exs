# PROTOTYPE 12b -- which exception class does each BEAM spelling produce?
#
# Ticket 12. Evidence for spelling the deliberate crash `raise` rather than
# `throw`. Provenance: local, Elixir 1.19.5 on OTP 28.
#
# Reproduce:  elixir 12b_raise_classes.exs
#
# Observed:
#   raise        -> {:error, %RuntimeError{message: "boom"}}
#   throw        -> {:throw, :boom}
#   exit         -> {:exit,  :boom}
#   :erlang.error-> {:error, :boom}
#
# The finding: `raise` produces the SAME class as :erlang.error/1 -- the one
# that kills processes and that `function_clause` belongs to. It is NOT the
# `throw` class.
#
# That is what rules out borrowing C#'s `throw`, despite C# 7 having exactly
# the right expression form (bottom-typed, legal in any value position). On the
# BEAM `throw` already names the CATCHABLE non-local-return class, so a BEAM
# reader would read `throw` in beam-sharp as recoverable -- the opposite of the
# intended meaning. A false friend that fails unsafe, unlike `as` (ticket 08),
# which fails to false.
#
# Borrow heuristic in action: tier 1 (C#) fails on SEMANTICS not syntax, so we
# fall to tier 2 (the BEAM) and find `raise` already spelled there.

probe = fn f ->
  try do
    f.()
  catch
    kind, reason -> {kind, reason}
  end
end

IO.inspect(probe.(fn -> raise "boom" end), label: "raise       ")
IO.inspect(probe.(fn -> throw(:boom) end), label: "throw       ")
IO.inspect(probe.(fn -> exit(:boom) end), label: "exit        ")
IO.inspect(probe.(fn -> :erlang.error(:boom) end), label: "erlang:error")
IO.puts("elixir #{System.version()} / otp #{:erlang.system_info(:otp_release)}")
