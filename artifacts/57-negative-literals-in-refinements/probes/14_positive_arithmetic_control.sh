#!/usr/bin/env bash
# Control: is `Id(2 + 3)` into a refined param refused TODAY with positive numbers? (i.e. is `0 - 5` failing for a sign reason?)
source "$(dirname "$0")/lib.sh"
probe PosArith "type Pos = int where value >= 1 and value <= 100
public int Id(Pos p)
Id(p) -> p
public int Go()
Go() -> Id(2 + 3)" Go 2>&1 | sed 's#/tmp/tmp\.[A-Za-z0-9]*/##'
