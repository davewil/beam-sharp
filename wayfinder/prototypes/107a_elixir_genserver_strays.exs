defmodule Counter do
  use GenServer
  @impl true
  def init(seed), do: {:ok, seed}
  @impl true
  def handle_call(:get, _from, s), do: {:reply, s, s}
  def handle_call({:add, n}, _from, s), do: {:reply, s + n, s + n}
  # no handle_info defined: `use GenServer` injects a default
end

defmodule NarrowInfo do
  use GenServer
  @impl true
  def init(seed), do: {:ok, seed}
  @impl true
  def handle_info(:tick, s), do: {:noreply, s + 1}
end

Process.flag(:trap_exit, true)
Logger.configure(level: :warning)

{:ok, p} = GenServer.start_link(Counter, 5)
IO.puts("get           = #{inspect(GenServer.call(p, :get))}")
send(p, :stray_message)
Process.sleep(100)
IO.puts("after stray send (default handle_info): alive=#{Process.alive?(p)}")
r = try do GenServer.call(p, :bogus, 1000) catch :exit, e -> {:exit, elem(e, 0) |> elem(0)} end
IO.puts("bogus call    = #{inspect(r)}  alive=#{Process.alive?(p)}")

{:ok, q} = GenServer.start_link(NarrowInfo, 0)
send(q, :stray_message)
Process.sleep(100)
IO.puts("narrow handle_info + stray send: alive=#{Process.alive?(q)}")
