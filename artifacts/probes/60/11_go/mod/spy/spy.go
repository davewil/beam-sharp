package spy

import "acme/billing/internal/ledger"

func Peek(c int) int { return ledger.Post(c) }
