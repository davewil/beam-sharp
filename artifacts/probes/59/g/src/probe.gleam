// Gleam 1.18.1: what does the generated Erlang do for public vs private functions taking a custom type / Int?
pub type Order {
  Order(id: Int, total: Int)
}

pub type Invoice {
  Invoice(id: Int, total: Int)
}

pub type Cart {
  Cart(item: Order, n: Int)
}

// opaque: constructors hidden outside the module, the runtime term is still a bare tagged tuple
pub opaque type Token {
  Token(value: Int)
}

pub fn make_token(v: Int) -> Token {
  Token(v)
}

pub fn pub_amount(o: Order) -> Int {
  o.total
}

fn priv_amount(o: Order) -> Int {
  o.total
}

pub fn via_cart(c: Cart) -> Int {
  priv_amount(c.item)
}

pub fn pub_inc(n: Int) -> Int {
  n + 1
}

fn priv_inc(n: Int) -> Int {
  n + 1
}

pub fn via_n(c: Cart) -> Int {
  priv_inc(c.n)
}

pub fn token_value(t: Token) -> Int {
  t.value
}

// a pattern in a head IS a runtime tag test, public or private
fn priv_match(o: Order) -> Int {
  let Order(id: _, total: t) = o
  t
}

pub fn via_match(o: Order) -> Int {
  priv_match(o)
}
