module Bench

record Order { Id: int, Total: int }

public int RunInt(int n)
RunInt(n) -> LoopInt(n, 0)

private int LoopInt(int n, int acc)
LoopInt(n, acc) when n <= 0 -> acc
LoopInt(n, acc) -> LoopInt(n - 1, Step(acc))

private int Step(int a)
Step(a) -> a + 1

public int RunRec(int n)
RunRec(n) -> LoopRec(n, Order{ Id = 1, Total = 1 }, 0)

private int LoopRec(int n, Order o, int acc)
LoopRec(n, o, acc) when n <= 0 -> acc
LoopRec(n, o, acc) -> LoopRec(n - 1, o, acc + Get(o))

private int Get(Order o)
Get(o) -> o.Total
