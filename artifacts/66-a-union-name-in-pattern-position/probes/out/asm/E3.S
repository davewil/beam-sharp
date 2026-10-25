{module, 'E3'}.  %% version = 0

{exports, [{'Handle',1},{bs@type_atoms,0},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 11}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,'E3'},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,{literal,['E3.A','E3.B','E3.E','Id','Kind',none]},{x,0}}.
    return.


{function, 'Handle', 1, 4}.
  {label,3}.
    {line,[{location,"ex/E3/e3.bs",10}]}.
    {func_info,{atom,'E3'},{atom,'Handle'},1}.
  {label,4}.
    {bif,map_get,{f,6},[{atom,'Kind'},{x,0}],{x,1}}.
    {select_val,{x,1},{f,6},{list,[{atom,'E3.A'},{f,5},{atom,'E3.B'},{f,5}]}}.
  {label,5}.
    {move,{atom,c},{x,0}}.
    return.
  {label,6}.
    {test,is_eq_exact,{f,3},[{x,0},{atom,none}]}.
    return.


{function, module_info, 0, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,'E3'},{atom,module_info},0}.
  {label,8}.
    {move,{atom,'E3'},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 10}.
  {label,9}.
    {line,[]}.
    {func_info,{atom,'E3'},{atom,module_info},1}.
  {label,10}.
    {move,{x,0},{x,1}}.
    {move,{atom,'E3'},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
