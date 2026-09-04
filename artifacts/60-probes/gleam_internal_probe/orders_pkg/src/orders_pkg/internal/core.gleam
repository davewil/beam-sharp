// `@internal` is an EXPLICIT per-definition attribute (not automatic just from
// being under an `internal/` path segment - measured separately: a bare `pub
// fn` under `internal/` was NOT auto-demoted, see NOTES.md). It hides the
// function from generated docs, completions, and the published `.gleam.pkg`
// interface used by DOWNSTREAM HEX PACKAGES - it is not a per-caller or
// per-module "friend" check enforced by the type checker against source.
@internal
pub fn recompute_total() {
  41 + 1
}
