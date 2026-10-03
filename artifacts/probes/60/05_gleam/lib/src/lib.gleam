import lib/internal/store
import lib/hidden/vault

pub fn charge(x: Int) -> Int {
  store.put(x) + vault.open(x)
}

// A function in a public module, marked @internal.
@internal
pub fn sneaky(x: Int) -> Int {
  x + 1000
}

pub fn use_sneaky(x: Int) -> Int {
  sneaky(x)
}

@internal
pub type Hidden {
  Hidden(Int)
}

pub fn exposes_hidden() -> Hidden {
  Hidden(1)
}
