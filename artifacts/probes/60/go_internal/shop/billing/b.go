package billing
import "example.com/proj/shop/internal/rows"
func Total() int { return rows.Recompute() }
