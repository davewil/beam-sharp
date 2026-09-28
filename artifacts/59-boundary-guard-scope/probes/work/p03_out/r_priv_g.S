{module, r_priv_g}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{run,2}]}.

{attributes, []}.

{labels, 10}.


{function, run, 2, 2}.
  {label,1}.
    {line,[{location,"r_priv_g.erl",3}]}.
    {func_info,{atom,r_priv_g},{atom,run},2}.
  {label,2}.
    {bif,map_get,{f,1},[{atom,'Kind'},{x,1}],{x,2}}.
    {test,is_eq_exact,{f,1},[{x,2},{atom,'Order'}]}.
    {move,{integer,0},{x,2}}.
    {call_only,3,{f,4}}. % loop/3


{function, loop, 3, 4}.
  {label,3}.
    {line,[{location,"r_priv_g.erl",4}]}.
    {func_info,{atom,r_priv_g},{atom,loop},3}.
  {label,4}.
    {'%',{var_info,{x,1},[{type,{t_map,any,any}}]}}.
    {'%',{var_info,{x,2},[{type,number}]}}.
    {test,is_eq_exact,{f,5},[{x,0},{integer,0}]}.
    {bif,map_get,{f,5},[{atom,'Kind'},{tr,{x,1},{t_map,any,any}}],{x,3}}.
    {test,is_eq_exact,{f,5},[{x,3},{atom,'Order'}]}.
    {move,{x,2},{x,0}}.
    return.
  {label,5}.
    {bif,map_get,{f,3},[{atom,'Kind'},{tr,{x,1},{t_map,any,any}}],{x,3}}.
    {test,is_eq_exact,{f,3},[{x,3},{atom,'Order'}]}.
    {line,[{location,"r_priv_g.erl",5}]}.
    {gc_bif,'-',{f,0},3,[{x,0},{integer,1}],{x,0}}.
    {bif,map_get,{f,0},[{atom,total},{tr,{x,1},{t_map,any,any}}],{x,3}}.
    {gc_bif,'+',{f,0},4,[{tr,{x,2},number},{x,3}],{x,2}}.
    {call_only,3,{f,4}}. % loop/3


{function, module_info, 0, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,r_priv_g},{atom,module_info},0}.
  {label,7}.
    {move,{atom,r_priv_g},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 9}.
  {label,8}.
    {line,[]}.
    {func_info,{atom,r_priv_g},{atom,module_info},1}.
  {label,9}.
    {move,{x,0},{x,1}}.
    {move,{atom,r_priv_g},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
