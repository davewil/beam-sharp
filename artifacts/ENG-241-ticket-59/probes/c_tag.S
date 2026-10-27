{module, c_tag}.  %% version = 0

{exports, [{f,1},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 9}.


{function, f, 1, 2}.
  {label,1}.
    {line,[{location,"/tmp/p3_12388/c_tag.erl",3}]}.
    {func_info,{atom,c_tag},{atom,f},1}.
  {label,2}.
    {bif,map_get,{f,1},[{atom,kind},{x,0}],{x,1}}.
    {test,is_eq_exact,{f,1},[{x,1},{atom,t}]}.
    {call_only,1,{f,4}}. % g/1


{function, g, 1, 4}.
  {label,3}.
    {line,[{location,"/tmp/p3_12388/c_tag.erl",4}]}.
    {func_info,{atom,c_tag},{atom,g},1}.
  {label,4}.
    {'%',{var_info,{x,0},[{type,{t_map,any,any}}]}}.
    {bif,map_get,{f,3},[{atom,kind},{tr,{x,0},{t_map,any,any}}],{x,1}}.
    {test,is_eq_exact,{f,3},[{x,1},{atom,t}]}.
    {bif,map_get,{f,0},[{atom,v},{tr,{x,0},{t_map,any,any}}],{x,0}}.
    return.


{function, module_info, 0, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,c_tag},{atom,module_info},0}.
  {label,6}.
    {move,{atom,c_tag},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,c_tag},{atom,module_info},1}.
  {label,8}.
    {move,{x,0},{x,1}}.
    {move,{atom,c_tag},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
