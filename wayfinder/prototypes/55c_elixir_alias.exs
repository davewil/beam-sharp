# 55c — Elixir: the BEAM neighbour with a struct syntax closest to beam-sharp's
# records (a tagged map), and the one whose set-theoretic types beam-sharp tracks.
#
# Measured:
#   1. Does the struct pattern name its type?  %Frame{...} — mandatory, like a
#      beam-sharp record CONSTRUCTION and unlike a beam-sharp record PATTERN.
#   2. Where does the whole-value binder go — left or right of `=`?
#   3. Is there a BARE map pattern that matches a struct without naming it?
#      (This is beam-sharp's `{ Kind: :'Shop.Frame' }` question exactly.)
#   4. Does the bare map pattern have to hand-write the struct tag?
#
# Run:  elixir 55c_elixir_alias.exs

defmodule Frame do
  defstruct [:type, :channel, :payload]
end

defmodule Probe do
  # (1)+(2) type named, binder on the RIGHT of `=`.
  def right_binder(%Frame{type: :method} = f), do: {:method_right, f.channel}
  def right_binder(_), do: :other

  # (2) binder on the LEFT of the same `=`.
  def left_binder(x) do
    case x do
      f = %Frame{type: :header} -> {:header_left, f.channel}
      _ -> :other
    end
  end

  # (3)+(4) a BARE map pattern, no struct name. To pin it to Frame you must
  # hand-write the __struct__ tag — which is Elixir's version of beam-sharp
  # asking a user to type `{ Kind: :'Shop.Frame' }`.
  def bare_map(%{__struct__: Frame, type: :body} = f), do: {:body_bare, f.channel}
  def bare_map(_), do: :other

  # (3) a bare map pattern that does NOT name the struct at all: it matches the
  # struct AND any plain map with that key. This is the collision beam-sharp's
  # ticket 48 measured against Elixir's Descr.
  def untagged(%{type: t} = whole), do: {:untagged, t, map_size(whole)}

  # The nested shape exemplar 25c writes: aliased struct inside a tuple.
  def nested({%Frame{type: :method} = f, rest}), do: {:nested, f.channel, rest}
  def nested(_), do: :other
end

# Built with `struct/2` rather than the `%Frame{}` literal: in a .exs script the
# top level is the same compilation context that defines the struct, and a literal
# there is a CompileError. The patterns inside the modules above are unaffected —
# they live in their own context, which is the thing being measured.
m = struct(Frame, type: :method, channel: 7, payload: "hello")
h = struct(Frame, type: :header, channel: 9, payload: "")
b = struct(Frame, type: :body, channel: 11, payload: "x")

IO.puts("1-2 type named, binder RIGHT : #{inspect(Probe.right_binder(m))}")
IO.puts("2   binder LEFT              : #{inspect(Probe.left_binder(h))}")
IO.puts("3-4 bare map + handwritten tag: #{inspect(Probe.bare_map(b))}")
IO.puts("3   untagged map matches struct: #{inspect(Probe.untagged(m))}")
IO.puts("3   ...and a plain map too     : #{inspect(Probe.untagged(%{type: :plain}))}")
IO.puts("    nested in a tuple (25c)    : #{inspect(Probe.nested({m, :rest}))}")
