import shop/internal/tax
pub fn gross(n: Int) -> Int { n + tax.recompute_tax(n) }
@internal
pub fn helper(n: Int) -> Int { n }
