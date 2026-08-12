# 16a — What Elixir's structs-and-protocols dispatch actually keys on
#
# Run: elixir wayfinder/prototypes/16a_elixir_protocol_dispatch.exs
# Verified: Elixir 1.19.5, Erlang/OTP 28 (local)
#
# Raised against ticket 16 by David, 2026-08-12: "Elixir solves dispatch by
# using structs and protocols." This probe establishes *how*, because the answer
# determines whether it is available to beam-sharp after ticket 09 removed
# nominal identity from the language.
#
# Note the struct literal `%User{}` is deliberately avoided — it is expanded at
# compile time and cannot see a module defined in the same file. `struct/2`
# builds the identical term at runtime.

defmodule User  do defstruct [:name, :age] end
defmodule Admin do defstruct [:name, :age] end   # IDENTICAL field set to User

defprotocol Describe do
  def describe(x)
end

defimpl Describe, for: User  do def describe(_), do: "a user"  end
defimpl Describe, for: Admin do def describe(_), do: "an admin" end
defimpl Describe, for: List  do def describe(_), do: "a list"  end

u = struct(User,  name: "d", age: 1)
a = struct(Admin, name: "d", age: 1)

IO.puts("1. A struct IS a map carrying an atom tag — nothing more")
IO.inspect(u, structs: false, label: "   term")
IO.puts("   __struct__ holds an atom? #{is_atom(u.__struct__)} -> #{inspect(u.__struct__)}")

IO.puts("\n2. Identical field sets; the tag is the whole discriminator")
IO.puts("   User  -> #{Describe.describe(u)}")
IO.puts("   Admin -> #{Describe.describe(a)}")
IO.puts("   fields identical once the tag is dropped? " <>
        "#{Map.drop(u, [:__struct__]) == Map.drop(a, [:__struct__])}")

IO.puts("\n3. The impl is found by naming a module from the tag")
IO.puts("   impl_for(user) = #{inspect(Describe.impl_for(u))}")
IO.puts("   impl_for([])   = #{inspect(Describe.impl_for([]))}")

IO.puts("\n4. THE LOAD-BEARING RESULT — dispatch reads the data, not a declared type")
fake = %{__struct__: Admin, name: "forged", age: 99}
IO.puts("   hand-built plain map carrying __struct__: Admin -> #{Describe.describe(fake)}")
IO.puts("   it went through no Admin constructor; is_struct/2 still says #{is_struct(fake, Admin)}")

IO.puts("""

  Conclusion. There is no nominal type identity anywhere in this mechanism —
  Elixir has no static types at all. `defimpl ... for: User` names a module at
  compile time, but what dispatch *reads* is an atom sitting in the term. The
  name is data.

  Two consequences for beam-sharp, both recorded on ticket 16:

  - The mechanism transplants. It is ticket 09 §5's tuple-tag remedy in map
    form, and needs no nominal identity to work.
  - Result 4 is also independent local evidence for ticket 09 §5's claim that
    the BEAM has no construction discipline: the tag is forgeable, so even
    Elixir's own "nominal-looking" dispatch is defeated by a hand-built term.
""")
