package orders

import "acme/billing"

func Total(c int) int { return billing.Charge(c) + billing.Open(c).Amount }
