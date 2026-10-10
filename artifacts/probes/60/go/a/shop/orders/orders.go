package orders

import "example.com/app/shop/orders/internal/totals"

func Total(c int) int { return totals.Recompute(c) }
