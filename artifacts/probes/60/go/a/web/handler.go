package web

import "example.com/app/shop/orders/internal/totals"

func Handle(c int) int { return totals.Recompute(c) }
