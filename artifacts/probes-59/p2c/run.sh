#!/bin/bash
# Does erlc remove a private function's boundary test when its callers prove it? Counts tests inside priv/1.
cd "$(dirname "$0")"; rm -rf w; mkdir w
w() { cat > w/$1.erl; }
TAG="map_get('Kind', O) == 'M.Order'"
# A: int, caller proves
w a_int_proved <<'E'
-module(a_int_proved). -export([pub/1]).
pub(X) when is_integer(X) -> priv(X).
priv(X) when is_integer(X) -> X + 1.
E
# B: int, caller does NOT prove (control: test must stay)
w b_int_unproved <<'E'
-module(b_int_unproved). -export([pub/1]).
pub(X) -> priv(X).
priv(X) when is_integer(X) -> X + 1.
E
# C: int, two callers, one proves one does not (control)
w c_int_mixed <<'E'
-module(c_int_mixed). -export([pub/1,pub2/1]).
pub(X) when is_integer(X) -> priv(X).
pub2(X) -> priv(X).
priv(X) when is_integer(X) -> X + 1.
E
# D: tag, caller proves with same guard
w d_tag_proved <<'E'
-module(d_tag_proved). -export([pub/1]).
pub(O) when map_get('Kind', O) == 'M.Order' -> priv(O).
priv(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
E
# E: tag, caller unguarded (control)
w e_tag_unproved <<'E'
-module(e_tag_unproved). -export([pub/1]).
pub(O) -> priv(O).
priv(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
E
# F: tag, caller builds the record literally
w f_tag_built <<'E'
-module(f_tag_built). -export([pub/1]).
pub(N) -> priv(#{'Kind' => 'M.Order', f1 => N}).
priv(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
E
# G: tag, caller pattern-matches the tag in the head
w g_tag_pattern <<'E'
-module(g_tag_pattern). -export([pub/1]).
pub(#{'Kind' := 'M.Order'} = O) -> priv(O).
priv(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
E
count() { # file flags -> module-wide counts of boundary tests (module_info excluded), plus the same inside priv/1
  erlc $2 -S -o w w/$1.erl
  awk '/^\{function, module_info,/{p=0;next} /^\{function,/{p=1} p' w/$1.S | tr -d ' \n' > w/$1.all
  ti=$(grep -o "{test,is_integer" w/$1.all | wc -l); tg=$(grep -o "{bif,map_get,{f,[1-9][0-9]*},\[{atom,'Kind'}" w/$1.all | wc -l)
  printf "%-18s %-9s module-wide: is_integer_tests=%s  tag_tests=%s\n" $1 "${2:-default}" $ti $tg
}
for f in a_int_proved b_int_unproved c_int_mixed d_tag_proved e_tag_unproved f_tag_built g_tag_pattern; do
  count $f ""; count $f "+inline"
done
