module Main exposing (f)
type Shape = Circle | Square
f : Shape -> Int
f s = case s of
  _ -> 1
  Square -> 2
