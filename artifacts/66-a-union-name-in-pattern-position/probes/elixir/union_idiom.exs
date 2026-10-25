# Elixir has no or-pattern in a function head; a "union of structs" is spelled in the guard.
defmodule A do defstruct [:id] end
defmodule B do defstruct [:id] end
defmodule E do defstruct [:id] end

defmodule U do
  # idiom 1: is_struct/2 disjunction, value bound whole
  def one(x) when is_struct(x, A) or is_struct(x, B), do: {:member, x.id}
  def one(_), do: :other
  # idiom 2: module in [..] after a %module{} pattern
  def two(%module{} = x) when module in [A, B], do: {:member, x.id}
  def two(_), do: :other
  # idiom 3: the clause for a non-member struct that no one ever reaches is not diagnosed by the compiler
  def three(x) when is_struct(x, A) or is_struct(x, B), do: :ab
  def three(%E{}), do: :e
end

defmodule Main do
  def run do
    for f <- [:one, :two], v <- [struct(A, id: 1), struct(B, id: 2), struct(E, id: 3), 5] do
      IO.inspect({f, v, apply(U, f, [v])})
    end
    IO.inspect(U.three(struct(E, id: 1)))
  end
end
Main.run()
