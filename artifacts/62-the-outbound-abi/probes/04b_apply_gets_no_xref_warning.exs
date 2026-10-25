# Probe 04b: control for 04 -- the SAME typo through apply/3 is silent at compile time; through the quoted call it warns.
Code.prepend_path(System.get_env("BS_EBIN"))
defmodule C2 do
  def via_apply(id), do: apply(:Shop, :Nwe, [id])
  def via_quoted(id), do: :Shop."Nwe"(id)
end
