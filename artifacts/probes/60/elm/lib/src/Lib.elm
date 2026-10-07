module Lib exposing (total)
import Lib.Internal
total : Int -> Int
total x = Lib.Internal.recompute x
