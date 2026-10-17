# P7: can a compile-time version check lean on what already exists on the BEAM?
# Reads real `vsn` values from the .app files OTP and Elixir installed here, and asks
# Elixir's own Version module whether it can parse and compare them.
apps = [:kernel, :stdlib, :ssl, :crypto, :elixir, :logger, :mix]
for a <- apps do
  :ok = :application.load(a) |> then(fn {:error, {:already_loaded, _}} -> :ok; :ok -> :ok end)
  {:ok, vsn} = :application.get_key(a, :vsn)
  vsn = List.to_string(vsn)
  parsed = case Version.parse(vsn) do {:ok, v} -> "parses as #{v}"; :error -> "REFUSED by Version.parse/1" end
  IO.puts(String.pad_trailing("#{a} #{vsn}", 22) <> parsed)
end
IO.puts("")
IO.puts("Version.match?(\"1.14.0\", \"~> 1.14\")  = #{Version.match?("1.14.0", "~> 1.14")}")
IO.puts("Version.match?(\"1.2.3\", \"~> 1.2\")    = #{Version.match?("1.2.3", "~> 1.2")}   <- fakereq's vsn against a '~>' requirement")
