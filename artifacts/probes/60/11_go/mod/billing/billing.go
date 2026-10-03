package billing

import "acme/billing/internal/ledger"

func Charge(c int) int { return ledger.Post(c) }

// A public function returning an internal type: Go allows it.
func Open(c int) ledger.Entry { return ledger.Entry{Amount: c} }
