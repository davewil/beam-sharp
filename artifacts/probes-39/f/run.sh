for o in "" "+inline"; do
  mkdir -p o$([ -n "$o" ] && echo i); d=o$([ -n "$o" ] && echo i)
  erlc $o -o $d st.erl
  echo "== erlc $o"; erl -noshell -pa $d -eval 'try st:f(0) catch C:R:S -> io:format("~p ~p~n~p~n",[C,R,S]) end, halt().'
done
