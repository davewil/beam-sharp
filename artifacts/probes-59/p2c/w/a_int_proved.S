{module, a_int_proved}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{pub,1}]}.

{attributes, []}.

{labels, 7}.


{function, pub, 1, 2}.
  {label,1}.
    {line,[{location,"w/a_int_proved.erl",2}]}.
    {func_info,{atom,a_int_proved},{atom,pub},1}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.
    {line,[{location,"w/a_int_proved.erl",3}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, module_info, 0, 4}.
  {label,3}.
    {line,[]}.
    {func_info,{atom,a_int_proved},{atom,module_info},0}.
  {label,4}.
    {move,{atom,a_int_proved},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,a_int_proved},{atom,module_info},1}.
  {label,6}.
    {move,{x,0},{x,1}}.
    {move,{atom,a_int_proved},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
