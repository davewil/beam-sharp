#!/usr/bin/env bash
# Probe 4: patched scratch bsc (alias-emit.diff, BS_ALIAS=wrap|dup) -> does `:Shop.new(1)` work from Elixir, what does
# module_info(exports) look like, how do stack traces / dialyzer / Elixir tooling see the alias?  Controls: unpatched build must NOT have `new`.
. "$(dirname "$0")/common.sh"
PATCHED=/tmp/bsb_62_x/ebin
[ -d $PATCHED ] || { echo "patched build missing: rebuild per brief"; exit 1; }
BSC_EBIN=/tmp/bsbuild/ebin build_shop $SCR/p4none
BSC_EBIN=$PATCHED BS_ALIAS=wrap BS_ALIAS_SPEC=1 build_shop $SCR/p4wrap
BSC_EBIN=$PATCHED BS_ALIAS=dup  BS_ALIAS_SPEC=1 build_shop $SCR/p4dup
BSC_EBIN=$PATCHED BS_ALIAS=wrap BS_ALIAS_SPEC=0 build_shop $SCR/p4wrapnospec
cat > $SCR/p4.exs <<'EXS'
[tag, dir] = System.argv()
Code.prepend_path(dir)
IO.puts("=== #{tag} ===")
ex = :Shop.module_info(:exports) |> Enum.sort()
IO.inspect(ex, label: "exports", limit: :infinity)
call = fn s -> try do {:ok, Code.eval_string(s) |> elem(0)} rescue e -> {:raised, e.__struct__} end end
IO.inspect(call.(":Shop.new(1)"), label: ":Shop.new(1)")
IO.inspect(call.(":Shop.\"New\"(1)"), label: ":Shop.\"New\"(1)")
IO.inspect(call.("import :Shop, only: [new: 1]; new(2)"), label: "import :Shop, only: [new: 1]")
IO.inspect(call.(":Shop.band(Shop.New(1))" |> String.replace("Shop.New", ":Shop.\"New\"")), label: ":Shop.band(order)  (Band/1 -> band/1)")
IO.inspect(call.(":Shop.nonexistent_alias(1)"), label: ":Shop.nonexistent_alias(1) (CONTROL: must raise)")
IO.inspect(function_exported?(:Shop, :new, 1), label: "function_exported?(:Shop, :new, 1)")
IO.inspect(Code.ensure_loaded?(:Shop), label: "Code.ensure_loaded?")
# stack trace through alias vs pascal: crash with wrong tag
bad = fn f -> try do apply(:Shop, f, [%{Kind: :"X.Y", Id: 1, Total: 2}]) rescue e -> {e.__struct__, Exception.format_stacktrace(__STACKTRACE__) |> String.split("\n") |> Enum.take(3) |> Enum.map(&String.trim/1)} end end
IO.inspect(bad.(:Which), label: "crash via Which")
IO.inspect(bad.(:which), label: "crash via which (alias)")
# Elixir's own tooling: h/1 style listing and docs chunk
IO.inspect(Code.fetch_docs(:Shop), label: "Code.fetch_docs")
EXS
for v in none wrap dup; do elixir $SCR/p4.exs $v $SCR/p4$v 2>&1 | grep -v '^warning' ; echo; done
echo "=== beam sizes (bytes) Shop.beam: none/wrap/dup/wrap-nospec ==="
for v in none wrap dup wrapnospec; do printf '%s %s\n' $v $(stat -c %s $SCR/p4$v/Shop.beam); done
echo "=== abstract form of the aliases in the wrap build (.abstr is the compiler's on-disk Abstract Format) ==="
cat > $SCR/p4show.erl <<'ERL'
-module(p4show).
-export([main/1]).
main(F) ->
    {ok, Forms} = file:consult(F),
    [io:format("~s", [erl_pp:form(X)]) || X <- Forms,
        (element(1, X) =:= function andalso lists:member(element(3, X), ['New', new, 'Which', which])) orelse
        (element(1, X) =:= spec andalso lists:member(element(1, element(3, X)), [{'New',1}, {new,1}]))].
ERL
(cd $SCR && erlc p4show.erl) && erl -noshell -pa $SCR -eval "p4show:main(\"$SCR/p4wrap/Shop.abstr\"), halt()."
