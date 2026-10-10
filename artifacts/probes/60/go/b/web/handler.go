package web

import "example.com/app/shop/internal/totals"

func Handle(c int) int { return totals.Recompute(c) }
