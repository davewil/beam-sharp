module Acme exposing (charge)

import Acme.Internal.Store as Store

charge : Int -> Int
charge x = Store.put x
