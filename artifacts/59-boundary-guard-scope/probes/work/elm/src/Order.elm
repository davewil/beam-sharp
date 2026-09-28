module Order exposing (Order, make, total)
type Order = Order { total : Int }
make : Int -> Order
make n = Order { total = n }
total : Order -> Int
total (Order o) = o.total
