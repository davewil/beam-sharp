defmodule Greeter.Extra do
  def shout(name) when is_binary(name), do: "HEY " <> name
end
