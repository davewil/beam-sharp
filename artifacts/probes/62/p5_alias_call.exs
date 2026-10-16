Code.prepend_path(System.get_env("P62OUT"))
IO.inspect(:Shop.new(1), label: ":Shop.new(1) with snake alias")
IO.inspect(:Shop.which(%{Kind: :"Shop.Order", Id: 1, Total: 2}), label: ":Shop.which(record)")
IO.inspect(:Shop."New"(1) == :Shop.new(1), label: "alias agrees with PascalCase export")
