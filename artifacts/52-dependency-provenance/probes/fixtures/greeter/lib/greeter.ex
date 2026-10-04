defmodule Greeter do
  # Deliberately uses only binary construction and guards: no remote call into
  # Elixir.Kernel, because Elixir 1.14's own beams cannot load on OTP 28 here.
  def hello(name) when is_binary(name), do: "hello, " <> name
end
