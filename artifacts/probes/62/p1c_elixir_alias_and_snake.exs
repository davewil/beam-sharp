# PROBE 1c — Elixir 1.14: (i) `alias :Api, as: Api` then `Api."New"(1)`; (ii) with snake aliases
# present, `:Api.get_x(1)` is plain Elixir. Env: BS_EBIN (dir with Api.beam); run twice, plain and alias build.
#
# EXPECTED (before run):
#   both builds: `alias :Api, as: Api` compiles in a module and `Api."New"(1)` returns the record
#   (so an Elixir file can say Api."New"(1) with a module alias, no apply/3).
#   plain build:  :Api.get_x(1) raises UndefinedFunctionError.
#   alias build:  :Api.get_x(1) = 2 ; :Api.http_get is NOT defined (Gleam rule gives h_t_t_p_get:
#                 :Api.h_t_t_p_get(1) = 3) -- the acronym case is visible in what the Elixir caller types;
#                 :Api.parse2_ints(1) = 5 ; :Api.get__x(1) = 4 (underscore name `Get_X`).
Code.prepend_path(System.get_env("BS_EBIN"))
[{c, _}] = Code.compile_string(~S'''
defmodule AliasCaller do
  alias :Api, as: Api
  def go, do: Api."New"(1)
end
''')
IO.inspect(c.go(), label: "alias :Api, as: Api ; Api.\"New\"(1)")
t = fn s -> try do {v, _} = Code.eval_string(s); inspect(v) rescue e -> "raised " <> inspect(e.__struct__) end end
for s <- [":Api.get_x(1)", ":Api.h_t_t_p_get(1)", ":Api.parse2_ints(1)", ":Api.get__x(1)", ":Api.http_get(1)"] do
  IO.puts(String.pad_trailing(s, 24) <> t.(s))
end
IO.puts("exports: " <> inspect(:Api.module_info(:exports) |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()))
