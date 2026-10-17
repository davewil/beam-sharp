package billing
import "example.com/shop/shop/billing/internal/ledger"
func Charge(n, t int) int { return ledger.Recompute(n, t) }
