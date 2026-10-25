#!/usr/bin/env bash
# P2: can a user type shadow a builtin type name? (lexer: builtin types lowercase, user types PascalCase)
# Also: user type/record named like a reserved qualifier or protocol (Map, List, Enumerable); control: Money.
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
D=$S/65/p2; rm -rf $D; mkdir -p $D/src/T
try(){ # label, body
  printf 'module T\n\n%s\n\npublic int Go(int n)\nGo(n) -> n\n' "$2" > $D/src/T/T.bs
  echo "== $1: $2"; $S/bsc --src-root $D/src $D/src/T Go 1 2>&1 | head -5; }
try "lowercase type alias int" 'type int = string'
try "lowercase record list"    'record list { X: int }'
try "lowercase type atom"      'type atom = int'
try "record named Map"         'record Map { X: int }'
try "record named List"        'record List { X: int }'
try "record named Enumerable"  'record Enumerable { X: int }'
try "type alias Map"           'type Map = int'
try "control: record Money"    'record Money { X: int }'
