pub type ViewCounts =
  List(#(String, Int))

pub fn maybe_views(row: ViewCounts) -> Result(ViewCounts, Nil) {
  row
}
