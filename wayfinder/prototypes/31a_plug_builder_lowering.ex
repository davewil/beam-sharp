defmodule Probe.Quota do
  @moduledoc "A module plug, so init/1's compile-time hoisting is observable."
  @behaviour Plug

  # If Plug hoists this, the ARITHMETIC runs at compile time and the RESULT is baked
  # into the generated pipeline as a literal.
  @impl true
  def init(opts), do: {:limit, Keyword.fetch!(opts, :limit) * 7}

  @impl true
  def call(conn, {:limit, n}), do: Plug.Conn.put_private(conn, :limit, n)
end

defmodule Probe.Pipeline do
  @moduledoc """
  31b — is Plug.Builder's stage set fixed at compile time, and what does halting compile to?
  """
  use Plug.Builder

  plug(:trace)
  plug(:auth)
  plug(:quota)
  plug(Probe.Quota, limit: 13)

  def trace(conn, _), do: Plug.Conn.put_private(conn, :log, [:trace | log(conn)])

  def auth(conn, _) do
    conn = Plug.Conn.put_private(conn, :log, [:auth | log(conn)])

    case Plug.Conn.get_req_header(conn, "authorization") do
      [] -> conn |> Plug.Conn.send_resp(401, "unauthorized") |> Plug.Conn.halt()
      _ -> conn
    end
  end

  def quota(conn, _), do: Plug.Conn.put_private(conn, :log, [:quota | log(conn)])

  defp log(conn), do: Map.get(conn.private, :log, [])
end

defmodule Probe do
  def run do
    IO.puts("=== 1. Does the pipeline run, and does halt stop it? ===")

    for authed <- [true, false] do
      conn = Plug.Test.conn(:get, "/")
      conn = if authed, do: Plug.Conn.put_req_header(conn, "authorization", "bearer x"), else: conn
      out = Probe.Pipeline.call(conn, [])

      IO.puts(
        "authed=#{authed} -> status=#{inspect(out.status)} halted=#{out.halted} " <>
          "ran=#{inspect(Enum.reverse(Map.get(out.private, :log, [])))}"
      )
    end

    IO.puts("\n=== 2. Is the stage set baked into call/2 at compile time? ===")
    IO.puts("Generated function bodies from the abstract_code chunk:\n")

    {_, beam, _} = :code.get_object_code(Probe.Pipeline)
    {:ok, {_, [abstract_code: {:raw_abstract_v1, forms}]}} =
      :beam_lib.chunks(beam, [:abstract_code])

    forms
    |> Enum.filter(&match?({:function, _, _, 2, _}, &1))
    |> Enum.each(fn form ->
      {:function, _, name, arity, _} = form
      IO.puts("--- #{name}/#{arity} ---")
      IO.puts(IO.iodata_to_binary(:erl_pp.function(form)))
    end)

    IO.puts("\n=== 3. Is a stage a value, or a name resolved at compile time? ===")
    IO.puts("Plug.Builder.@plugs is a module attribute consumed by __before_compile__.")
    IO.puts("halted is a field on the struct: #{inspect(Map.has_key?(%Plug.Conn{}, :halted))}")
  end
end
