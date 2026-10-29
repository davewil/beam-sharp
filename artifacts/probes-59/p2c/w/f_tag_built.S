{module, f_tag_built}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{pub,1}]}.

{attributes, []}.

{labels, 9}.


{function, pub, 1, 2}.
  {label,1}.
    {line,[{location,"w/f_tag_built.erl",2}]}.
    {func_info,{atom,f_tag_built},{atom,pub},1}.
  {label,2}.
    {put_map_assoc,{f,0},
                   {literal,#{'Kind' => 'M.Order'}},
                   {x,0},
                   1,
                   {list,[{atom,f1},{x,0}]}}.
    {call_only,1,{f,4}}. % priv/1


{function, priv, 1, 4}.
  {label,3}.
    {line,[{location,"w/f_tag_built.erl",3}]}.
    {func_info,{atom,f_tag_built},{atom,priv},1}.
  {label,4}.
    {'%',{var_info,{x,0},[{type,{t_map,{t_atom,['Kind',f1]},any}}]}}.
    {bif,map_get,
         {f,3},
         [{atom,'Kind'},{tr,{x,0},{t_map,{t_atom,['Kind',f1]},any}}],
         {x,1}}.
    {test,is_eq_exact,{f,3},[{x,1},{atom,'M.Order'}]}.
    {bif,map_get,
         {f,0},
         [{atom,f1},{tr,{x,0},{t_map,{t_atom,['Kind',f1]},any}}],
         {x,0}}.
    return.


{function, module_info, 0, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,f_tag_built},{atom,module_info},0}.
  {label,6}.
    {move,{atom,f_tag_built},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,f_tag_built},{atom,module_info},1}.
  {label,8}.
    {move,{x,0},{x,1}}.
    {move,{atom,f_tag_built},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
