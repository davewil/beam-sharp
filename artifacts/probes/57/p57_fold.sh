#!/usr/bin/env bash
# Ticket 57. For each refinement text: does the checker accept it? Every case is a fresh module.
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d)
try() {   # try LABEL 'type body'
  mkdir -p "$W/M"; printf 'module M\n\ntype T = %s\n\npublic int Id(T x)\n\nId(x) -> x\n' "$2" > "$W/M/m.bs"
  out=$(bsc -o "$W/out" "$W/M" 2>&1); rc=$?
  printf '%-34s rc=%s %s\n' "$1" "$rc" "$(echo "$out" | head -1 | cut -c1-90)"
}
try 'ge -5'            'int where value >= -5'
try 'ge -5 and le 5'   'int where value >= -5 and value <= 5'
try 'ge 1 or le -1'    'int where value >= 1 or value <= -1'
try 'le 3 or ge 10 (ctl)' 'int where value <= 3 or value >= 10'
try 'ne 0 (ctl)'       'int where value != 0'
try 'ne -1'            'int where value != -1'
try 'ge 2+3'           'int where value >= 2 + 3'
try 'ge 0-5'           'int where value >= 0 - 5'
try 'ge (-5)'          'int where value >= (-5)'
try 'ge - -5'          'int where value >= - -5'
try 'ge 2*3'           'int where value >= 2 * 3'
try 'ge 0 (ctl)'      'int where value >= 0'
try 'lt -5 (lhs)'      'int where -5 <= value'
