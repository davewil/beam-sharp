#!/usr/bin/env bash
# 60/h : Erlang `-doc false` and Elixir `@moduledoc false`/`@doc false` are documentation-only; Elixir's tracer hook is
# the mechanism a Boundary-style library uses to refuse a call. EXECUTED against local erl/elixir.
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cd "$w"
echo "== Erlang: -doc false on an exported function; another module calls it"
cat > e1.erl <<'EOF'
-module(e1).
-export([secret/0]).
-doc false.
secret() -> 42.
EOF
cat > e2.erl <<'EOF'
-module(e2).
-export([go/0]).
go() -> e1:secret().
EOF
erlc e1.erl e2.erl && erl -noshell -pa . -eval 'io:format("e2:go() = ~p~n",[e2:go()]), halt().'
echo "== Elixir: @moduledoc false / @doc false / defp, and a compiler tracer that refuses calls by caller module"
cat > ex.exs <<'EOF'
defmodule Shop.Orders.Internal do
  @moduledoc false
  @doc false
  def recompute(x), do: x + 1
  defp hidden(x), do: x
end
defmodule Tools.Rogue do
  def peek(x), do: Shop.Orders.Internal.recompute(x)
end
IO.inspect(Tools.Rogue.peek(1), label: "no tracer: Tools.Rogue.peek(1)")

defmodule Boundaryish do
  # the whole of a 'callee says who may call' rule, as an Elixir compiler tracer
  def trace({:remote_function, meta, Shop.Orders.Internal, name, arity}, env) do
    unless String.starts_with?(inspect(env.module), "Shop.Orders") do
      raise CompileError, line: meta[:line], description:
        "#{inspect(env.module)} may not call Shop.Orders.Internal.#{name}/#{arity}"
    end
    :ok
  end
  def trace(_, _), do: :ok
end
Code.put_compiler_option(:tracers, [Boundaryish])
try do
  Code.compile_string("defmodule Tools.Rogue2 do\n  def peek(x), do: Shop.Orders.Internal.recompute(x)\nend")
  IO.puts("tracer: rogue ACCEPTED")
rescue e in CompileError -> IO.puts("tracer: refused -> " <> Exception.message(e))
end
Code.compile_string("defmodule Shop.Orders.Total do\n  def t(x), do: Shop.Orders.Internal.recompute(x)\nend")
IO.puts("tracer: Shop.Orders.Total accepted")
EOF
elixir ex.exs 2>&1 | grep -v "Setting\|^ \{20\}"
