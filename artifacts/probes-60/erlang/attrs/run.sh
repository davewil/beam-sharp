cd "$(dirname "$0")"; echo "## erlc ea.erl (export_all)"; erlc ea.erl; echo "rc=$?"
echo "## erlc ea2.erl (export_all + nowarn_export_all)"; erlc ea2.erl; echo "rc=$?"
erl -noshell -eval 'io:format("non -export fn via export_all: ~p~n",[ea:hidden()]), io:format("opaque is plain tuple at runtime: ~p~n",[ea:new()]), halt().'
rm -f *.beam
