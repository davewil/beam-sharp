Code.prepend_path(".")
IO.inspect(:Api."New"(1), label: "direct")
IO.inspect(1 |> :Api."New"(), label: "piped")
IO.inspect((&:Api."New"/1).(2), label: "captured")
IO.inspect(:Api."HTTPGet"(1), label: "acronym")
IO.inspect(:Api."Get_X"(1), label: "underscore")
defmodule T do
  alias :Api, as: Api
  def a, do: Api."New"(3)
  def b, do: [1,2] |> Enum.map(&Api."New"/1)
  def c(m), do: m."New"(5)
end
IO.inspect(T.a()); IO.inspect(T.b()); IO.inspect(T.c(:Api))
for s <- [":Api.New(1)", ~S|:Api."New"(1)|, "&:Api.New/1", ~S|&:Api."New"/1|, "Api.New(1)", "mod.New(1)", ~S{1 |> :Api."New"()}] do
  IO.puts(s <> " => " <> inspect(Code.string_to_quoted(s)))
end
IO.puts(Code.format_string!(~S|:Api."New"(1)|) |> IO.iodata_to_binary())
