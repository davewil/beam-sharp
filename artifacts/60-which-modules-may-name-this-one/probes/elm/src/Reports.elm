module Reports exposing (gross)
import Internal.Tax as Tax
gross : Int -> Int
gross n = n + Tax.tax n
