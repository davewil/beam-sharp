#!/usr/bin/env bash
# Reproduce ticket 57's whole table with the real bsc (default: repo build; BSC=... overrides).
source "$(dirname "$0")/lib.sh"
mk () { printf '\ntype T = int where %s\npublic int Id(T b)\nId(b) -> b' "$1"; }
probe GeMinus5          "$(mk 'value >= -5')"
probe GeMinus5AndLe5    "$(mk 'value >= -5 and value <= 5')"
probe Ge1OrLeMinus1     "$(mk 'value >= 1 or value <= -1')"
probe Le3OrGe10         "$(mk 'value <= 3 or value >= 10')"
probe NeZero            "$(mk 'value != 0')"
probe Pattern_LeMinus1  '
public atom Sign(int n)
Sign(<= -1) -> :neg
Sign(_) -> :other'
