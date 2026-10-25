# Probe 04: the quoted-call spelling in a COMPILED module (not eval_string), formatter round-trip,
# nested module, pipe, and compile-time warnings for a typo (negative control: does the compiler check?).
Code.prepend_path(System.get_env("BS_EBIN"))
defmodule Caller do
  def make(id), do: :Shop."New"(id)
  def piped(id), do: id |> then(&:Shop."New"/1)
  def nested(o), do: :"Shop.Reports"."Fully"(o)
  def which(o), do: :Shop."Which"(o)
  def typo(id), do: :Shop."Nwe"(id)      # NEGATIVE CONTROL: no such export
  def cap, do: &:Shop."New"/1
end
IO.inspect(Caller.make(3), label: "make")
IO.inspect(Caller.which(Caller.make(3)), label: "which")
IO.inspect(Caller.piped(4), label: "piped")
IO.inspect(Caller.cap().(5), label: "capture")
IO.inspect((try do Caller.typo(1) rescue e -> e.__struct__ end), label: "typo (expect UndefinedFunctionError)")
IO.inspect(Code.format_string!(~S|:Shop."New"(1)|) |> IO.iodata_to_binary(), label: "formatter keeps quotes?")
IO.inspect(Code.format_string!(~S|:Shop."new"(1)|) |> IO.iodata_to_binary(), label: "formatter on lowercase-quoted")
IO.inspect(Macro.to_string(quote(do: :Shop."New"(1))), label: "to_string")
IO.inspect(quote(do: :Shop."New"(1)), label: "AST")
IO.inspect(quote(do: :shop.new(1)), label: "AST lowercase for comparison")
