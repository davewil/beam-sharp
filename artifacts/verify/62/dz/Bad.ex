defmodule BadCaller do
  def typo(id), do: :Shop."Nwe"(id)
  def arity(id), do: :Shop."New"(id, id)
  def wrongtype(), do: :Shop."New"("not an int")
  def ok(id), do: :Shop."New"(id)
end
