package total

import "example.com/shop/shop/orders/internal/pricing"

func Total(n int) int { return pricing.RecomputeTotal(n) }
