# PROTOTYPE 26b -- is an Elixir struct an EXACT field set, and what does that cost?
# For ticket 26. Elixir is the largest shipped design that erases a "record" to a map with a
# name in it, so what its field-set discipline actually enforces is evidence, not analogy.

defmodule Order do
  defstruct [:id, :total, status: :open]
end

defmodule Invoice do
  defstruct [:id, :total, status: :open]   # DELIBERATELY identical fields to Order
end

defmodule Main do
  def run do
    IO.puts("Elixir #{System.version()} / OTP #{System.otp_release()}\n")

    o = %Order{id: 1, total: 2}
    i = %Invoice{id: 1, total: 2}

    IO.puts("--- 1. the term a struct actually is ---")
    IO.inspect(Map.from_struct(o), label: "  Order without __struct__")
    IO.inspect(:maps.to_list(o) |> Enum.sort(), label: "  Order as a raw map")
    IO.puts("  map_size(%Order{})                        : #{map_size(o)}")

    IO.puts("\n--- 2. do identical-field structs compare equal? ---")
    IO.puts("  %Order{id: 1,total: 2} == %Invoice{id: 1,total: 2} : #{o == i}")
    IO.puts("  ...with __struct__ stripped from both              : #{Map.from_struct(o) == Map.from_struct(i)}")
    IO.puts("  => the ONLY thing distinguishing them is the tag's VALUE. Strip it and they are")
    IO.puts("     the same term -- which is exactly ticket 09's 'two names over the same set'.")

    IO.puts("\n--- 3. is the field set EXACT? (bears on ticket 27 sec7, no row polymorphism) ---")
    r = try do
      Map.replace!(%Order{id: 1}, :nope, 1)
    rescue e -> {:raised, e.__struct__}
    end
    IO.inspect(r, label: "  Map.replace!(:nope, 1) on a struct")

    r2 = try do
      Code.eval_string("%Order{id: 1, nope: 2}", [], __ENV__)
    rescue e -> {:raised, e.__struct__, Exception.message(e) |> String.slice(0, 60)}
    end
    IO.inspect(r2, label: "  %Order{nope: 2} at compile time  ")

    IO.puts("\n--- 4. but is exactness ENFORCED on the term? ---")
    widened = Map.put(o, :sneaked_in, true)
    IO.puts("  Map.put(%Order{}, :sneaked_in, true) map_size      : #{map_size(widened)}")
    IO.puts("  is_struct(widened, Order)                          : #{is_struct(widened, Order)}")
    IO.puts("  does it still match %Order{} ?                     : #{match?(%Order{}, widened)}")
    IO.puts("  => exactness is a COMPILE-TIME courtesy of the %Order{} literal only. The term")
    IO.puts("     model does not carry it, and nothing at runtime re-checks it.")

    IO.puts("\n--- 5. absent vs present-but-nil (bears on this ticket's sub-question 4) ---")
    IO.puts("  %Order{id: 1} status default                       : #{inspect(Map.get(%Order{id: 1}, :status))}")
    IO.puts("  :total when never supplied                         : #{inspect(Map.get(%Order{id: 1}, :total))}")
    IO.puts("  Map.has_key?(%Order{id: 1}, :total)                : #{Map.has_key?(%Order{id: 1}, :total)}")
    IO.puts("  => a struct has NO absent fields. Every key is always present; 'unset' is spelled")
    IO.puts("     as a value (nil). Elixir declined to distinguish absence from nothing-ness.")

    IO.puts("\n--- 6. is the tag forgeable? (ticket 09 sec5, re-verified) ---")
    forged = %{__struct__: Order, id: 99, total: 0, status: :open}
    IO.puts("  hand-built plain map with __struct__: Order")
    IO.puts("  is_struct(forged, Order)                           : #{is_struct(forged, Order)}")
    IO.puts("  match?(%Order{}, forged)                           : #{match?(%Order{}, forged)}")
    IO.puts("  forged == %Order{id: 99, total: 0}                 : #{forged == %Order{id: 99, total: 0}}")
  end
end

Main.run()
