defmodule UseIt do
  def run do
    a = :Shop."New"(1)
    b = 2 |> :Shop."New"()
    f = &:Shop."New"/1
    c = f.(3)
    d = Enum.map([4, 5], &:Shop."New"/1)
    e = :Shop."Which"(a)
    alias_trap = try do Shop."New"(1) rescue x -> x.__struct__ end
    {a, b, c, d, e, alias_trap}
  end
end
