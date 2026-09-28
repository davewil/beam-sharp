{module, a_tg_u}.  %% version = 0

{exports, [{f,1},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 7}.


{function, f, 1, 2}.
  {label,1}.
    {line,[{location,"a_tg_u.erl",3}]}.
    {func_info,{atom,a_tg_u},{atom,f},1}.
  {label,2}.
    {bif,map_get,{f,0},[{atom,total},{x,0}],{x,0}}.
    return.


{function, module_info, 0, 4}.
  {label,3}.
    {line,[]}.
    {func_info,{atom,a_tg_u},{atom,module_info},0}.
  {label,4}.
    {move,{atom,a_tg_u},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,a_tg_u},{atom,module_info},1}.
  {label,6}.
    {move,{x,0},{x,1}}.
    {move,{atom,a_tg_u},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
