{module, b_int_unproved}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{pub,1}]}.

{attributes, []}.

{labels, 10}.


{function, pub, 1, 2}.
  {label,1}.
    {line,[{location,"w/b_int_unproved.erl",2}]}.
    {func_info,{atom,b_int_unproved},{atom,pub},1}.
  {label,2}.
    {test,is_integer,{f,3},[{x,0}]}.
    {line,[{location,"w/b_int_unproved.erl",3}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.
  {label,3}.
    {call_only,1,{f,9}}. % '-inlined-priv/1-'/1


{function, module_info, 0, 5}.
  {label,4}.
    {line,[]}.
    {func_info,{atom,b_int_unproved},{atom,module_info},0}.
  {label,5}.
    {move,{atom,b_int_unproved},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,b_int_unproved},{atom,module_info},1}.
  {label,7}.
    {move,{x,0},{x,1}}.
    {move,{atom,b_int_unproved},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.


{function, '-inlined-priv/1-', 1, 9}.
  {label,8}.
    {line,[{location,"w/b_int_unproved.erl",3}]}.
    {func_info,{atom,b_int_unproved},{atom,'-inlined-priv/1-'},1}.
  {label,9}.
    {jump,{f,8}}.
