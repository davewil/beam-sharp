defmodule MyLib.Request do
  defstruct method: nil, opts: []
  def method(%__MODULE__{method: m}), do: m
end
defmodule MyLib do
  def new(opts), do: %MyLib.Request{method: :get, opts: opts}
  def upcase(s), do: String.upcase(s)
end
