defmodule Acme.Pay do
  defmodule Store do
    @moduledoc false
    def put(x), do: x + 100
  end
  def go(x), do: Store.put(x)
end

defmodule Acme.Outsider do
  # `defmodule Store` inside `Acme.Pay` is just the module Acme.Pay.Store plus a lexical alias.
  def go(x), do: Acme.Pay.Store.put(x)
end
