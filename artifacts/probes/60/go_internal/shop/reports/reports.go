package reports
import "example.com/shop/shop/billing/internal/ledger"
func Restate(n int) int { return ledger.Recompute(n, 0) }
