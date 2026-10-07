package orders
import "example.com/probe/shop/orders/internal/cache"
func Total(x int) int { return cache.Get(x) }
