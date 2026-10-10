package orders

import "example.com/app/shop/internal/totals"

func Total(c int) int { return totals.Recompute(c) }
