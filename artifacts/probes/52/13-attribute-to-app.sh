#!/usr/bin/env bash
# CLAIM (mine): (1) a ~20-line escript turns the attribute into an `applications` list; (2) WITHOUT a declaration
# the same list can be INFERRED from the beam's imports chunk, but only for modules that are present on the machine
# doing the inferring -- which is exactly not the machine the ticket worries about.
# REFUTED IF: inference with the dependency ABSENT still names `mylib`; or the declared list is empty for ShopA.
. "$(dirname "$0")/lib.sh"
O=$WORK/o13; rm -rf "$O"; mkdir -p "$O/decl" "$O/undecl"
ERL_LIBS=$MYLIBS "$PBSC" -o "$O/decl"   "$BS/ShopA" >/dev/null
ERL_LIBS=$MYLIBS "$PBSC" -o "$O/undecl" "$BS/ShopC" >/dev/null
echo "### ShopA (declared), the dependency PRESENT on the code path of the tool"
ERL_LIBS=$MYLIBS escript "$ROOT/bs_apps.escript" "$O/decl"
echo "### ShopC (undeclared), dependency PRESENT"
ERL_LIBS=$MYLIBS escript "$ROOT/bs_apps.escript" "$O/undecl"
echo "### ShopC (undeclared), dependency ABSENT (e.g. the fleet's machine)"
env -u ERL_LIBS escript "$ROOT/bs_apps.escript" "$O/undecl"
echo "### ShopA (declared), dependency ABSENT"
env -u ERL_LIBS escript "$ROOT/bs_apps.escript" "$O/decl"
echo "### size of the tool: $(wc -l < "$ROOT/bs_apps.escript") lines"
