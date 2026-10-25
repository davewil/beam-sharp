module Main exposing (take)

type Shape = A Int | B Int | E Int

take : Shape -> Int
take x =
    case x of
        A i | B i -> i
        E _ -> 0
