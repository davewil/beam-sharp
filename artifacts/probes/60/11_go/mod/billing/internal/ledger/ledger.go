package ledger

type Entry struct{ Amount int }

func Post(c int) int { return c + 1 }
