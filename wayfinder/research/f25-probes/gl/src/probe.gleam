pub type CartResult {
  Numeric(List(#(String, Int)))
  Text(List(#(String, String)))
  Expired(String)
}

pub fn cart(form: List(#(String, String))) -> CartResult {
  form
}

pub type ViewCounts =
  List(#(String, Int))

pub fn page_views(row: List(#(String, String))) -> ViewCounts {
  row
}

pub fn maybe_views(row: List(#(String, String))) -> Result(ViewCounts, Nil) {
  Ok(row)
}
