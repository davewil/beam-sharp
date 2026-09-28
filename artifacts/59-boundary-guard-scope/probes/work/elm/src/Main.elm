module Main exposing (main)
import Order
forged = Order.Order { total = 7 }
main = Order.total forged
