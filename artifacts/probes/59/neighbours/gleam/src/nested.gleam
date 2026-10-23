pub type Line {
  Line(qty: Int, price: Int)
}

pub type Order {
  Order(id: Int, lines: List(Line))
}

pub fn total(o: Order) -> Int {
  sum_lines(o.lines)
}

fn sum_lines(ls: List(Line)) -> Int {
  case ls {
    [] -> 0
    [l, ..t] -> line_total(l) + sum_lines(t)
  }
}

// private; reads fields with no tag check of its own
fn line_total(l: Line) -> Int {
  l.qty * l.price
}
