defmodule GenericProbe do
  # A "generic function" shaped exactly like beam-sharp's Reverse/2 corpus case
  # (25e's ReverseParts :: list<binary>, list<binary> -> list<binary> and
  # ReverseRows :: list<Iodata>, list<Iodata> -> list<Iodata>).
  #
  # Elixir has no compile-time generics construct at all -- this @spec is
  # documentation/dialyzer input only, never checked by `elixirc`.
  @spec reverse(list(a), list(a)) :: list(a) when a: var
  def reverse([], acc), do: acc
  def reverse([x | rest], acc), do: reverse(rest, [x | acc])

  # Two "instantiations", exactly the corpus shape -- no duplication needed,
  # because there is no compile-time uniqueness-per-signature rule to violate.
  def reverse_bytes(xs), do: reverse(xs, [])
  def reverse_strings(xs), do: reverse(xs, [])

  # THE PROBE: deliberately break the single-variable-per-call-site contract
  # that a real generic would enforce (mixing an integer and an atom into ONE
  # call, which a true `a` type variable could not admit both of at once).
  def mismatched do
    reverse([1, 2, :not_an_int, 3], [])
  end
end

IO.inspect(GenericProbe.reverse_bytes([1, 2, 3]), label: "reverse_bytes")
IO.inspect(GenericProbe.reverse_strings(["a", "b"]), label: "reverse_strings")
IO.inspect(GenericProbe.mismatched(), label: "mismatched (should be a type error in a real generic system)")
