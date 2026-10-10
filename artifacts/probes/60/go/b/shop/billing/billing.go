package billing

import "example.com/app/shop/internal/totals"

func Invoice(c int) int { return totals.Recompute(c) }
