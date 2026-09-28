{module, b_g}.  %% version = 0

{exports, [{c,1},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 9}.


{function, p, 1, 2}.
  {label,1}.
    {line,[{location,"b_g.erl",3}]}.
    {func_info,{atom,b_g},{atom,p},1}.
  {label,2}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {test,is_ge,{f,1},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {test,is_ge,{f,1},[{integer,255},{tr,{x,0},{t_integer,any}}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, c, 1, 4}.
  {label,3}.
    {line,[{location,"b_g.erl",4}]}.
    {func_info,{atom,b_g},{atom,c},1}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.
    {test,is_ge,{f,3},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {test,is_ge,{f,3},[{integer,255},{tr,{x,0},{t_integer,any}}]}.
    {call_only,1,{f,2}}. % p/1


{function, module_info, 0, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,b_g},{atom,module_info},0}.
  {label,6}.
    {move,{atom,b_g},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,b_g},{atom,module_info},1}.
  {label,8}.
    {move,{x,0},{x,1}}.
    {move,{atom,b_g},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
