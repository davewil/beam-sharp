package reports

import "example.com/shop/shop/orders/internal/pricing"

func Report(n int) int { return pricing.RecomputeTotal(n) }
