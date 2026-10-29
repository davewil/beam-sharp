{module, c_int_mixed}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{pub,1},{pub2,1}]}.

{attributes, []}.

{labels, 12}.


{function, pub, 1, 2}.
  {label,1}.
    {line,[{location,"w/c_int_mixed.erl",2}]}.
    {func_info,{atom,c_int_mixed},{atom,pub},1}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.
    {line,[{location,"w/c_int_mixed.erl",4}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, pub2, 1, 4}.
  {label,3}.
    {line,[{location,"w/c_int_mixed.erl",3}]}.
    {func_info,{atom,c_int_mixed},{atom,pub2},1}.
  {label,4}.
    {test,is_integer,{f,5},[{x,0}]}.
    {line,[{location,"w/c_int_mixed.erl",4}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.
  {label,5}.
    {call_only,1,{f,11}}. % '-inlined-priv/1-'/1


{function, module_info, 0, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,c_int_mixed},{atom,module_info},0}.
  {label,7}.
    {move,{atom,c_int_mixed},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 9}.
  {label,8}.
    {line,[]}.
    {func_info,{atom,c_int_mixed},{atom,module_info},1}.
  {label,9}.
    {move,{x,0},{x,1}}.
    {move,{atom,c_int_mixed},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.


{function, '-inlined-priv/1-', 1, 11}.
  {label,10}.
    {line,[{location,"w/c_int_mixed.erl",4}]}.
    {func_info,{atom,c_int_mixed},{atom,'-inlined-priv/1-'},1}.
  {label,11}.
    {jump,{f,10}}.
