# Elixir side of probe 64/08
IO.puts("Elixir #{System.version()} / OTP #{System.otp_release()}")
m_present_nil = %{a: nil}
m_absent = %{}
IO.puts("-- Map.get/3 default (nil): ambiguous")
IO.inspect(Map.get(m_present_nil, :a), label: "Map.get(%{a: nil}, :a)       ")
IO.inspect(Map.get(m_absent, :a),      label: "Map.get(%{},       :a)       ")
IO.inspect(Map.get(m_present_nil, :a) == Map.get(m_absent, :a), label: "indistinguishable?        ")
IO.puts("-- Map.fetch/2: tagged, distinguishes")
IO.inspect(Map.fetch(m_present_nil, :a), label: "Map.fetch(%{a: nil}, :a)     ")
IO.inspect(Map.fetch(m_absent, :a),      label: "Map.fetch(%{},       :a)     ")
IO.puts("-- Keyword.get ambiguity")
IO.inspect(Keyword.get([a: nil], :a), label: "Keyword.get([a: nil], :a)  ")
IO.inspect(Keyword.get([], :a),       label: "Keyword.get([], :a)        ")
IO.puts("-- Access (map[key]) is the nil-default form")
IO.inspect(m_present_nil[:a] == m_absent[:a], label: "map[:a] indistinguishable?")

IO.puts("\n-- Elixir 1.18.5's set-theoretic type module (Module.Types.Descr): does `term() | nil` collapse?")
alias Module.Types.Descr
t = Descr.term()
nilatom = Descr.atom([nil])
IO.inspect(Descr.equal?(Descr.union(t, nilatom), t), label: "term() | nil  ==  term()  ")
IO.inspect(Descr.equal?(Descr.union(Descr.integer(), nilatom), Descr.integer()), label: "integer() | nil == integer()")
tag = Descr.tuple([Descr.atom([:ok]), t])
IO.inspect(Descr.equal?(Descr.union(tag, Descr.atom([:error])), tag), label: "{:ok, term()} | :error == {:ok,term()}")
IO.inspect(Descr.subtype?(nilatom, t), label: "nil subtype of term()          ")
