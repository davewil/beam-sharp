# 15a — Does an untagged failure channel survive normalisation?
#
# Ticket 09 §4: "Normalise first, then check pairwise on the normalised members.
# `:ok | atom` *is* `atom` — the subset is absorbed by the algebra."
#
# Ticket 10 §5 put `type option<T> = T | :nothing;` in the prelude and wrote
# `ToExistingAtom(input) // atom | :nothing`. Ticket 11 gave `ValidateAs<T>`
# the return type `T | :error`.
#
# Question: when T already contains the failure atom, does the failure channel
# survive the algebra, or is it absorbed?
#
# Measured against a shipping implementation of the same theory:
# Elixir 1.19.5, Module.Types.Descr.

alias Module.Types.Descr

nothing = Descr.atom([:nothing])
error   = Descr.atom([:error])
any_atom = Descr.atom()
bool    = Descr.atom([true, false])
int     = Descr.integer()

show = fn label, descr ->
  IO.puts(String.pad_trailing(label, 40) <> inspect(descr))
end

IO.puts("\n=== baseline: the failure atoms themselves ===")
show.(":nothing", nothing)
show.(":error", error)
show.("atom()", any_atom)

IO.puts("\n=== option<T> = T | :nothing ===")
show.("option<int>   = int | :nothing", Descr.union(int, nothing))
show.("option<bool>  = bool | :nothing", Descr.union(bool, nothing))
show.("option<atom>  = atom | :nothing", Descr.union(any_atom, nothing))
show.("  ...compare bare atom()", any_atom)
show.(
  "  collapsed?",
  Descr.equal?(Descr.union(any_atom, nothing), any_atom)
)

IO.puts("\n=== ValidateAs<T> -> T | :error ===")
show.("ValidateAs<int>  = int | :error", Descr.union(int, error))
show.("ValidateAs<atom> = atom | :error", Descr.union(any_atom, error))
show.(
  "  collapsed?",
  Descr.equal?(Descr.union(any_atom, error), any_atom)
)

IO.puts("\n=== nesting: option<option<int>> ===")
inner = Descr.union(int, nothing)
outer = Descr.union(inner, nothing)
show.("option<int>", inner)
show.("option<option<int>>", outer)
show.("  collapsed to one level?", Descr.equal?(outer, inner))

IO.puts("\n=== the narrow case: T is exactly the failure atom ===")
show.("option<:nothing> = :nothing | :nothing", Descr.union(nothing, nothing))
show.("  equals :nothing?", Descr.equal?(Descr.union(nothing, nothing), nothing))

IO.puts("\n=== control: a tagged channel ===")
# (:ok, T) | (:error, E) — tuples of arity 2 with a distinct literal atom head.
ok_t = Descr.tuple([Descr.atom([:ok]), int])
err_t = Descr.tuple([Descr.atom([:error]), any_atom])
tagged = Descr.union(ok_t, err_t)
show.("(:ok, int) | (:error, atom)", tagged)
show.("  still two members?", not Descr.equal?(tagged, ok_t))
