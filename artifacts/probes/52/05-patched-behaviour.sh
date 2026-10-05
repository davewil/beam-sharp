#!/usr/bin/env bash
# Behaviour of the PROTOTYPE compiler (compiler-prototype.patch) on the three option programs.
# CLAIMS tested: (1) a declared app turns the run-time `error:undef` into a compile-time diagnostic;
# (2) per-using repeats the diagnostic once per `using`, per-module once; (3) the cheap check
# (code:lib_dir/1) verifies the app EXISTS, not that the module lives in it; (4) the beam carries the
# declaration as an attribute.
# REFUTED IF: A/B with ERL_LIBS unset compile (exit 0); OR ShopA yields 1 diagnostic (not 2) / ShopB yields
#   != 1; OR ShopLie (wrong app name, app present) is refused by the CHEAP check (then the check is stronger
#   than I say) or is ACCEPTED by BS_PROTO_STRONG; OR ShopTypo is accepted; OR the attribute is missing.
. "$(dirname "$0")/lib.sh"
O=$WORK/o05; rm -rf "$O"; mkdir -p "$O"
t() { echo "\$ [$1] bsc ${*:2}"; shift; env "${E[@]}" "$PBSC" -o "$O" "$@"; echo "[exit=$?]"; echo; }
E=(-u ERL_LIBS)
echo "######## ERL_LIBS unset"
for p in ShopC ShopA ShopB; do t "unset" "$BS/$p"; done
echo "######## variant C hook (module presence on every using, no syntax), ERL_LIBS unset"
E=(-u ERL_LIBS BS_PROTO_CHECK_MODULES=1); t "C-hook" "$BS/ShopC"
echo "######## ERL_LIBS correct"
E=(ERL_LIBS=$MYLIBS)
for p in ShopC ShopA ShopB; do t "libs" "$BS/$p" Verb; done
E=(ERL_LIBS=$MYLIBS BS_PROTO_CHECK_MODULES=1); t "libs+C-hook" "$BS/ShopC" Verb
echo "######## the declaration lies: right module, wrong app (stdlib) / typo (mylb) -- cheap check"
E=(ERL_LIBS=$MYLIBS); t "libs" "$BS/ShopLie" Verb; t "libs" "$BS/ShopTypo" Verb
echo "######## same, STRONG check (module must be found inside the declared app's directory)"
E=(ERL_LIBS=$MYLIBS BS_PROTO_STRONG=1); t "strong" "$BS/ShopLie" Verb; t "strong" "$BS/ShopA" Verb
echo "######## per-MODULE marker naming the wrong app (stdlib) while the module is in mylib: ERL_LIBS unset, then strong check"
E=(-u ERL_LIBS BS_PROTO_STRONG=1); t "B-lie,strong,no deps" "$BS/ShopBLie" Verb
# REFUTED (for 'per-module cannot catch a wrong app') IF the line above is refused at compile time.
echo "######## OTP modules with their app declared (crypto is not loaded at boot, stdlib is)"
E=(-u ERL_LIBS); t "unset" "$BS/ShopOtp" Digest '"abc"'
echo "######## what the beam carries"
for m in ShopA ShopB ShopC ShopOtp; do
  erl -noshell -eval '{ok,{_,[{attributes,A}]}}=beam_lib:chunks("'$O'/'$m'.beam",[attributes]), io:format("~s: ~p~n",["'$m'",[X||{K,_}=X<-A,K=:=bs_requires]]),halt().'
done
echo
echo "######## does the clean-room's reading surface (--api, nothing built) go through the check? ERL_LIBS unset"
echo '$ bsc --api ShopA   (prototype)'; env -u ERL_LIBS "$PBSC" --api "$BS/ShopA"; echo "[exit=$?]"
# REFUTED (for the claim "--api is unaffected") IF this exits non-zero or prints the app diagnostic.
echo
echo "######## the attribute is visible to the VM itself (module_info/1) and loading is unaffected"
erl -noshell -pa "$O" -eval 'io:format("~p~n",[[X||{bs_requires,_}=X<-'"'"'ShopA'"'"':module_info(attributes)]]), halt().'
