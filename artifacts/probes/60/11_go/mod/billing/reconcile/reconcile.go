package reconcile

import "acme/billing/internal/ledger"

func Run(c int) int { return ledger.Post(c) }
