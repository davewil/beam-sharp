#!/usr/bin/env bash
# CLAIM (mine): the BEAM's own tools already tell "calls a module that is not there" without any B# change
# (the beam's `imports` chunk), and NONE of them read a custom `-bs_requires` attribute.
# Tests with a bsc-emitted beam: xref (undefined_function_calls), dialyzer (unknown functions), systools
# (release script), rebar3 xref.  Each is run on the beam WITH and WITHOUT the attribute (prototype bsc).
# REFUTED IF: xref reports nothing for the missing module; or the report changes when the attribute is present
#   (then a tool reads it); or systools adds mylib to the script because of the attribute.
. "$(dirname "$0")/lib.sh"
O=$WORK/o08; rm -rf "$O"; mkdir -p "$O/plain" "$O/attr"
env -u ERL_LIBS "$PBSC" -o "$O/plain" "$BS/ShopC"
ERL_LIBS=$MYLIBS "$PBSC" -o "$O/attr" "$BS/ShopA"      # ShopA = same program with [app: mylib] markers
echo "### xref: undefined_function_calls over the emitted beam (mylib NOT added to xref's scope)"
for v in plain attr; do
erl -noshell -eval '
{ok,_}=xref:start(s), xref:set_default(s,[{warnings,false},{verbose,false}]),
{ok,_}=xref:add_directory(s,"'$O/$v'"),
{ok,R}=xref:analyze(s,undefined_function_calls),
io:format("~s: ~p~n",["'$v'",R]), halt().'
done
echo "### xref again, with the dependency's ebin added to the scope (Elixir's own ebin on the path: beam_lib needs its debug-info backend)"
erl -noshell -pa "$SCRATCH/env/lib/elixir/lib/elixir/ebin" -eval '
{ok,_}=xref:start(s), xref:set_default(s,[{warnings,false},{verbose,false}]),
{ok,_}=xref:add_directory(s,"'$O/attr'"), {ok,_}=xref:add_directory(s,"'$MYLIBS'/mylib/ebin"),
{ok,R}=xref:analyze(s,undefined_function_calls), io:format("undefined_function_calls: ~p~n",[R]), halt().'
echo
echo "### dialyzer (-Wunknown): does it name the missing remote? (builds a minimal PLT first)"
export HOME=$WORK/dhome; mkdir -p "$HOME"
# PLT_CACHE (optional, dev convenience only): reuse a PLT built by an earlier run of this very command.
if [ -n "${PLT_CACHE:-}" ] && [ -f "$PLT_CACHE" ]; then cp "$PLT_CACHE" "$WORK/min.plt"; echo "plt: reused $PLT_CACHE"
else T0=$(date +%s); dialyzer --build_plt --output_plt "$WORK/min.plt" --apps erts kernel stdlib >"$WORK/plt.log" 2>&1; echo "plt build: $(( $(date +%s)-T0 ))s (exit $?)"; fi
for v in plain attr; do echo "--- $v"; dialyzer --plt "$WORK/min.plt" -Wunknown "$O/$v/"*.beam 2>&1 | sed 's#/tmp[^ ]*/##' | head -8; done
echo
echo "### systools: does a release script carry what the beam attribute says?"
R=$WORK/rel; rm -rf "$R"; mkdir -p "$R/shopapp-1/ebin"
cp "$O/attr/ShopA.beam" "$R/shopapp-1/ebin/"
cat > "$R/shopapp-1/ebin/shopapp.app" <<'APP'
{application,shopapp,[{description,"x"},{vsn,"1"},{modules,['ShopA']},{registered,[]},{applications,[kernel,stdlib]}]}.
APP
cat > "$R/shop.rel" <<'REL'
{release,{"shop","1"},{erts,"16.4"},[{kernel,"10.6.3"},{stdlib,"7.3"},{shopapp,"1"}]}.
REL
( cd "$R" && erl -noshell -pa shopapp-1/ebin -eval 'R=systools:make_script("shop",[silent,{path,["shopapp-1/ebin"]}]), io:format("make_script: ~p~n",[element(1,R)]), halt().'
  echo "script mentions mylib? $(grep -c mylib shop.script)   mentions shopapp? $(grep -c shopapp shop.script)" )
echo "--- same release, .app now lists mylib in applications (what an author writes by hand today), mylib on the path"
sed -i 's/{applications,\[kernel,stdlib\]}/{applications,[kernel,stdlib,mylib]}/' "$R/shopapp-1/ebin/shopapp.app"
sed -i 's/{shopapp,"1"}\]}/{compiler,"9.0.6"},{elixir,"1.19.5"},{mylib,"0.3.1"},{shopapp,"1"}]}/' "$R/shop.rel"
( cd "$R" && erl -noshell -pa shopapp-1/ebin -eval 'R=systools:make_script("shop",[silent,{path,["shopapp-1/ebin","'$MYLIBS'/mylib/ebin","'$SCRATCH'/env/lib/elixir/lib/elixir/ebin"]}]), io:format("make_script: ~p~n",[R]), halt().'
  echo "script mentions mylib? $(grep -c mylib shop.script)" )
echo "--- and WITHOUT mylib on the path: the failure is at release build, by name"
( cd "$R" && erl -noshell -pa shopapp-1/ebin -eval 'R=systools:make_script("shop",[silent,{path,["shopapp-1/ebin"]}]), io:format("make_script: ~p~n",[R]), halt().' )
