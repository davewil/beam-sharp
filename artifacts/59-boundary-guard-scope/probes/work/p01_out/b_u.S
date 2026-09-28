{module, b_u}.  %% version = 0

{exports, [{c,1},{module_info,0},{module_info,1},{p,1}]}.

{attributes, []}.

{labels, 9}.


{function, p, 1, 2}.
  {label,1}.
    {line,[{location,"b_u.erl",3}]}.
    {func_info,{atom,b_u},{atom,p},1}.
  {label,2}.
    {bif,map_get,{f,0},[{atom,total},{x,0}],{x,0}}.
    return.


{function, c, 1, 4}.
  {label,3}.
    {line,[{location,"b_u.erl",4}]}.
    {func_info,{atom,b_u},{atom,c},1}.
  {label,4}.
    {bif,map_get,{f,3},[{atom,'Kind'},{x,0}],{x,1}}.
    {test,is_eq_exact,{f,3},[{x,1},{atom,'Wrapper'}]}.
    {bif,map_get,{f,0},[{atom,order},{tr,{x,0},{t_map,any,any}}],{x,0}}.
    {call_only,1,{f,2}}. % p/1


{function, module_info, 0, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,b_u},{atom,module_info},0}.
  {label,6}.
    {move,{atom,b_u},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,b_u},{atom,module_info},1}.
  {label,8}.
    {move,{x,0},{x,1}}.
    {move,{atom,b_u},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
