package billing
import "example.com/shop/orders/internal/pricing" // sibling of orders/: outside
var _ = pricing.Recompute
