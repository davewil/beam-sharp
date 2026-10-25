{module, 'E4'}.  %% version = 0

{exports, [{'Handle',1},{bs@type_atoms,0},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 11}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,'E4'},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,{literal,['E4.A','E4.B','E4.E','Id','Kind',none]},{x,0}}.
    return.


{function, 'Handle', 1, 4}.
  {label,3}.
    {line,[{location,"ex/E4/e4.bs",10}]}.
    {func_info,{atom,'E4'},{atom,'Handle'},1}.
  {label,4}.
    {test,is_map,{f,6},[{x,0}]}.
    {get_map_elements,{f,3},
                      {tr,{x,0},{t_map,any,any}},
                      {list,[{atom,'Kind'},{x,1}]}}.
    {select_val,{x,1},{f,3},{list,[{atom,'E4.A'},{f,5},{atom,'E4.B'},{f,5}]}}.
  {label,5}.
    {move,{atom,c},{x,0}}.
    return.
  {label,6}.
    {test,is_eq_exact,{f,3},[{x,0},{atom,none}]}.
    return.


{function, module_info, 0, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,'E4'},{atom,module_info},0}.
  {label,8}.
    {move,{atom,'E4'},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 10}.
  {label,9}.
    {line,[]}.
    {func_info,{atom,'E4'},{atom,module_info},1}.
  {label,10}.
    {move,{x,0},{x,1}}.
    {move,{atom,'E4'},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
