#!/usr/bin/env bash
# Ticket 57 (reach): refinements and guards share alternatives/1, so the literal a refinement refuses
# must also leave a GUARD unread — an arm whose guard holds `-1` credits no coverage.
# Expected column = the desired outcome (accepted). !! = today's compiler disagrees.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
probe NegGuardCovers accepted 'public atom Sign(int n)
Sign(n) when n < -1 -> :neg
Sign(n) when n >= -1 -> :nonneg'
probe PosGuardCovers accepted 'public atom Sign(int n)
Sign(n) when n < 1 -> :nonpos
Sign(n) when n >= 1 -> :pos'
probe NegPatCovers   accepted 'public atom Sign(int n)
Sign(<= -1) -> :neg
Sign(>= 0) -> :nonneg'
