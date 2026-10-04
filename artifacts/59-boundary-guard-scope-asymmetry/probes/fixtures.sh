# fixture for probes 02/05/06: a module whose private functions are reachable only through exported ones
write_forge_fixture() {  # $1 = dir to create Forge/ in
mkdir -p $1/Forge
cat > $1/Forge/forge.bs <<'BS'
module Forge
record Order { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255
record Cart  { Item: Order, Qty: int, Items: list<Order>, Oct: Octet }

// ---- private helpers: no exported entry of their own --------------------
int Inner(Order o)
Inner(o) -> o.Total

int Scale(int n)
Scale(n) -> n * 2

int ScaleO(Octet n)
ScaleO(n) -> n * 2

// the kind a body does not object to: compares, never computes
atom Big(int n)
Big(n) when n >= 100 -> :big
Big(n)               -> :small

int SumAll(list<Order> os, int acc)
SumAll([], acc)       -> acc
SumAll([o, ..rest], acc) -> SumAll(rest, acc + Inner(o))

// ---- exported entries ---------------------------------------------------
// path 1: the whole parameter is the record; the exported guard sees it
public int Direct(Order o)
Direct(o) -> Inner(o)

// path 2: a record NESTED in the parameter. Cart's own tag is tested, Item's is not
public int Nested(Cart c)
Nested(c) -> Inner(c.Item)

// path 3: an int FIELD of a record parameter handed to a private int function
public int Field(Cart c)
Field(c) -> Scale(c.Qty)

// path 3d: an OCTET-typed field (statically fine at the call site) into a private Octet function
public int Oct(Cart c)
Oct(c) -> ScaleO(c.Oct)

// path 3b: same, into a private function that only compares
public atom FieldBig(Cart c)
FieldBig(c) -> Big(c.Qty)

// path 4: a list of records, element type declared, never walked at the boundary
public int Sum(Cart c)
Sum(c) -> SumAll(c.Items, 0)

// path 4b: the list parameter itself (elements are never walked at the boundary: O(n))
public int SumList(list<Order> os)
SumList(os) -> SumAll(os, 0)

// path 4c: a private function passed as a VALUE over a forged list (its args are 'any' to the Erlang optimiser)
public list<int> Mapped(list<Order> os)
Mapped(os) -> List.Map(os, Inner)

// path 3c: NO private function at all: the exported body computes on a projected field itself
public atom Compare(Cart c)
Compare(c) -> c.Qty switch { >= 100 => :big, _ => :small }

// path 5: plain int through exported to private: the exported int guard stops it
public int ViaInt(int n)
ViaInt(n) -> Scale(n)
BS
}
