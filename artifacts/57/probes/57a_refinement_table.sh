#!/usr/bin/env bash
# 57a: re-run the ticket's table against the CURRENT compiler (2026-09-30 tree).
. "$(dirname "$0")/common.sh"
t () { probe "$1" "$2" "type T = int where $3
public int Id(T b)
Id(b) -> b"; }
echo "== the ticket's five rows =="
t R1 refused  'value >= -5'
t R2 refused  'value >= -5 and value <= 5'
t R3 refused  'value >= 1 or value <= -1'
t R4 accepted 'value <= 3 or value >= 10'
t R5 accepted 'value != 0'
echo "== fold variants: what would a checker fold have to reach? =="
t V1 refused  'value >= 0 - 5'
t V2 refused  'value >= 2 + 3'
t V3 refused  'value >= -(5)'
t V4 refused  'value >= - -5'
t V5 refused  'value >= -0'
t V6 refused  'value > -1'
t V7 refused  '-5 <= value'
t V8 refused  'value >= 5 - 10'
t V9 accepted 'value >= 5'
echo "== float: refused for a different reason (F51 'a float refinement, refused as opaque') =="
probe F1 refused 'type T = float where value >= 1.0
public float Id(T b)
Id(b) -> b'
probe F2 refused 'type T = float where value >= -1.0
public float Id(T b)
Id(b) -> b'
