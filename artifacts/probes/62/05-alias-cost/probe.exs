Code.prepend_path(System.get_env("BS_EBIN"))
IO.puts("-- patched Shop exports:")
IO.inspect(:Shop.module_info(:exports) |> Enum.reject(&(elem(&1,0) in [:module_info, :"bs@type_atoms"])) |> Enum.sort())
IO.puts("-- the thing the ticket wants:")
IO.inspect(:Shop.new(1), label: ":Shop.new(1)")
IO.inspect(:Shop.which(:Shop.new(1)), label: ":Shop.which(:Shop.new(1))")
IO.inspect(:Shop."New"(1) == :Shop.new(1), label: "alias == original")
IO.puts("-- stack depth: alias is a tail call, so a crash through the alias shows:")
try do :Shop.which(%{}) rescue e -> IO.puts(Exception.format(:error, e, __STACKTRACE__) |> String.split("\n") |> Enum.take(4) |> Enum.join("\n")) end
