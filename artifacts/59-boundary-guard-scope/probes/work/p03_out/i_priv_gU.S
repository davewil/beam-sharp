{module, i_priv_gU}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{run,2}]}.

{attributes, []}.

{labels, 10}.


{function, run, 2, 2}.
  {label,1}.
    {line,[{location,"i_priv_gU.erl",3}]}.
    {func_info,{atom,i_priv_gU},{atom,run},2}.
  {label,2}.
    {call_only,2,{f,4}}. % loop/2


{function, loop, 2, 4}.
  {label,3}.
    {line,[{location,"i_priv_gU.erl",4}]}.
    {func_info,{atom,i_priv_gU},{atom,loop},2}.
  {label,4}.
    {test,is_eq_exact,{f,5},[{x,0},{integer,0}]}.
    {test,is_integer,{f,3},[{x,1}]}.
    {move,{x,1},{x,0}}.
    return.
  {label,5}.
    {test,is_integer,{f,3},[{x,0}]}.
    {test,is_integer,{f,3},[{x,1}]}.
    {line,[{location,"i_priv_gU.erl",5}]}.
    {gc_bif,'-',{f,0},2,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,2}}.
    {gc_bif,'+',
            {f,0},
            3,
            [{tr,{x,1},{t_integer,any}},{tr,{x,0},{t_integer,any}}],
            {x,1}}.
    {move,{x,2},{x,0}}.
    {call_only,2,{f,4}}. % loop/2


{function, module_info, 0, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,i_priv_gU},{atom,module_info},0}.
  {label,7}.
    {move,{atom,i_priv_gU},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 9}.
  {label,8}.
    {line,[]}.
    {func_info,{atom,i_priv_gU},{atom,module_info},1}.
  {label,9}.
    {move,{x,0},{x,1}}.
    {move,{atom,i_priv_gU},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
