#!/usr/bin/env bash
# Probe 07: Elixir 1.14 / Erlang OTP 25 -- is there a language-level "who may call this"?
# (a) @moduledoc false / @doc false only hide from docs; (b) a user-land compile tracer CAN enforce a
# callee-declared friend list because the compiler hands it the CALLER's env -- i.e. the checker delta
# is "know the caller's module at the call site", which bsc's import_env already has (Self).
elixir --version | tail -1
T=$(mktemp -d); cd "$T"
cat > a.exs <<'EOS'
defmodule Orders.Internal do
  @moduledoc false
  @doc false
  def recompute(n), do: n * 3
end
defmodule Billing do
  def bill(n), do: Orders.Internal.recompute(n)
end
IO.puts("a) Billing.bill(2) via a @moduledoc-false module = #{Billing.bill(2)}  (compiled and ran; nothing refused)")
EOS
elixir a.exs
cat > b.exs <<'EOS'
defmodule FriendTracer do
  # callee-declared: persisted attribute @friends on the callee; caller = env.module
  def trace({:remote_function, meta, callee, name, arity}, env) do
    friends = try do callee.__info__(:attributes)[:friends] rescue _ -> nil end
    if friends && env.module not in List.wrap(friends) && not Enum.any?(List.wrap(friends), &String.starts_with?(Atom.to_string(env.module), Atom.to_string(&1) <> ".")) do
      IO.puts("   TRACER REFUSES #{inspect(env.module)} -> #{inspect(callee)}.#{name}/#{arity} (line #{meta[:line]}), friends=#{inspect(friends)}")
    end
    :ok
  end
  def trace(_, _), do: :ok
end
Code.put_compiler_option(:tracers, [FriendTracer])
Code.compile_string("""
defmodule Orders.Internal do
  Module.register_attribute(__MODULE__, :friends, persist: true)
  @friends [Orders]
  def recompute(n), do: n * 3
end
""")
IO.puts("b) compiling Orders.Pricing (inside Orders) and Billing (outside):")
Code.compile_string("""
defmodule Orders.Pricing do def p(n), do: Orders.Internal.recompute(n) end
defmodule Billing do def bill(n), do: Orders.Internal.recompute(n) end
""")
IO.puts("   (a tracer only REPORTS; both modules still compiled and loaded: Billing.bill(2)=#{Billing.bill(2)})")
EOS
elixir b.exs

echo "c) Erlang: no caller-scoped export; the *after-the-fact* tool is xref (caller-graph query over .beam files):"
cat > callee.erl <<'EOS'
-module(callee). -export([helper/1]). helper(X) -> X * 3.
EOS
cat > friend.erl <<'EOS'
-module(friend). -export([go/1]). go(X) -> callee:helper(X).
EOS
cat > stranger.erl <<'EOS'
-module(stranger). -export([go/1]). go(X) -> callee:helper(X).
EOS
erlc +debug_info callee.erl friend.erl stranger.erl
erl -noshell -eval '
xref:start(s), xref:set_default(s, [{warnings,false}]), {ok,_} = xref:add_directory(s, "."),
{ok, Edges} = xref:analyze(s, {use, {callee,helper,1}}),
io:format("   xref {use,{callee,helper,1}} (functions that use it) = ~p~n", [Edges]),
io:format("   (it answers WHO calls, after compilation; it does not stop anyone)~n"), halt().' 2>&1
