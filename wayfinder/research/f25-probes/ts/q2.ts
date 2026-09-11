// Q2: an alias whose expansion carries the reason
type ViewCounts = Record<string, number>;

function pageViews(row: Record<string, unknown>): ViewCounts {
  return row;
}

function pageViewsMissing(rows: Record<string, unknown>[]): ViewCounts | "not_found" {
  if (rows.length === 0) return "not_found";
  return rows[0];
}
