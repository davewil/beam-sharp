module Main exposing (..)
import Dict
-- Elm: Dict.get returns Maybe v, always tagged; Maybe (Maybe a) stays distinguishable.
f : Dict.Dict String (Maybe Int) -> Maybe (Maybe Int)
f d = Dict.get "k" d
g : Int -> String
g n = case n of
  -5 -> "neg five"
  _ -> "other"
