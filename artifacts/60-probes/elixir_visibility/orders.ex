defmodule Orders do
  @moduledoc false  # hides the module from generated docs; NOT a compiler visibility control

  def public_api(), do: internal_helper() + 1

  # defp = private to THIS module only. No way to say "private to module X, Y
  # but callable from module Z" - the granularity is module-wide, binary
  # (exported or not), same as beam-sharp's own public/private per ticket 40 §3.
  defp internal_helper(), do: 41
end

defmodule Billing do
  def call_orders_private() do
    # Attempting to call a defp function from ANOTHER module - Elixir has no
    # syntax for this at all (there is no `Orders.internal_helper()` spelling
    # that reaches a defp function); this is a compile error, not a visibility
    # refusal with a friend list.
    Orders.internal_helper()
  end
end
