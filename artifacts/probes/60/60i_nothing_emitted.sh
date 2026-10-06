#!/usr/bin/env bash
# PROBE 60i -- ticket 60 (ENG-242). Claim: a compile-time caller check emits NOTHING (ticket 18 §5:
# per-function entry labels are exported-or-local; the BEAM has no caller-scoped export), so
# adding `visible_to Lab.Billing` to Lab.Grp.Core leaves its .beam byte-identical.
# Measure: compile the same sources with pristine bsc (declaration line removed) and patched bsc
# (declaration present); compare sha256 of every .beam and .abstr, and the export tables.
# Control: change one function body in a third compile; the hash MUST differ (probe can go red).
set -uo pipefail
: "${PRISTINE:?}" ; : "${PATCHED:?}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mk() { mkdir -p "$1/Lab/Grp/Core" "$1/Lab/Billing"
  printf 'module Lab.Grp.Core\n%s' "$2" > "$1/Lab/Grp/Core/index.bs"
  printf 'public int Sum(int a, int b)\nSum(a, b) -> a + %s\n' "${3:-b}" > "$1/Lab/Grp/Core/Sum.bs"
  printf 'module Lab.Billing\nusing Lab.Grp.Core\npublic int Bill(int n)\nBill(n) -> Sum(n, 1)\n' > "$1/Lab/Billing/Bill.bs"; }
# one source path for all three compiles: the `file` attribute in the beam carries it, so differing
# paths would change the hash for a reason that has nothing to do with the declaration.
V="$W/s"
b() { erl -noshell -pa "$1/ebin" -eval 'bsc:main(init:get_plain_arguments())' -extra --src-root "$2" -o "$3" "$2/Lab/Billing" >/dev/null 2>&1; }
rm -rf "$V"; mk "$V" ""; b "$PRISTINE" "$V" "$W/oa"
rm -rf "$V"; mk "$V" $'visible_to Lab.Billing\n'; b "$PATCHED" "$V" "$W/ob"
rm -rf "$V"; mk "$V" "" "b + 1"; b "$PATCHED" "$V" "$W/oc"
for f in Lab.Grp.Core.beam Lab.Grp.Core.abstr Lab.Billing.beam; do
  printf '%-22s pristine=%s patched+decl=%s patched,body-changed=%s\n' "$f" \
    "$(sha256sum "$W/oa/$f" | cut -c1-12)" "$(sha256sum "$W/ob/$f" | cut -c1-12)" "$(sha256sum "$W/oc/$f" | cut -c1-12)"
done
cat > "$W/cmp.escript" <<'E'
#!/usr/bin/env escript
%%
main([A, B]) ->
    {ok, {_, CA}} = beam_lib:chunks(A, [abstract_code, atoms, exports, attributes, "Code", "StrT", "ImpT", "ExpT"]),
    {ok, {_, CB}} = beam_lib:chunks(B, [abstract_code, atoms, exports, attributes, "Code", "StrT", "ImpT", "ExpT"]),
    Diff = [K || {K, V} <- CA, V =/= proplists:get_value(K, CB)],
    io:format("   chunks differing (of ~p compared): ~p~n", [length(CA), Diff]).
E
echo "chunk-level comparison, Lab.Grp.Core: pristine vs patched+decl (expect none), then vs body-changed (control, expect some)"
escript "$W/cmp.escript" "$W/oa/Lab.Grp.Core.beam" "$W/ob/Lab.Grp.Core.beam"
escript "$W/cmp.escript" "$W/oa/Lab.Grp.Core.beam" "$W/oc/Lab.Grp.Core.beam"
echo "bytes Lab.Grp.Core.beam: pristine=$(stat -c %s "$W/oa/Lab.Grp.Core.beam") patched+decl=$(stat -c %s "$W/ob/Lab.Grp.Core.beam")"
cd "$W"; erl -noshell -eval 'io:format("exports patched+decl: ~p~n", [begin code:add_patha(hd(init:get_plain_arguments())), {module,_}=code:ensure_loaded('"'"'Lab.Grp.Core'"'"'), '"'"'Lab.Grp.Core'"'"':module_info(exports) end]), halt().' -extra "$W/ob"
