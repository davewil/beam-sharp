package orders
import "example.com/shop/orders/internal/pricing"
func Total(x int) int { return pricing.Recompute(x) }
