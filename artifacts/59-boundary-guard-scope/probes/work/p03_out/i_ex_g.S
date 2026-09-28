{module, i_ex_g}.  %% version = 0

{exports, [{loop,2},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 8}.


{function, loop, 2, 2}.
  {label,1}.
    {line,[{location,"i_ex_g.erl",3}]}.
    {func_info,{atom,i_ex_g},{atom,loop},2}.
  {label,2}.
    {test,is_eq_exact,{f,3},[{x,0},{integer,0}]}.
    {test,is_integer,{f,1},[{x,1}]}.
    {move,{x,1},{x,0}}.
    return.
  {label,3}.
    {test,is_integer,{f,1},[{x,0}]}.
    {test,is_integer,{f,1},[{x,1}]}.
    {line,[{location,"i_ex_g.erl",4}]}.
    {gc_bif,'-',{f,0},2,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,2}}.
    {gc_bif,'+',
            {f,0},
            3,
            [{tr,{x,1},{t_integer,any}},{tr,{x,0},{t_integer,any}}],
            {x,1}}.
    {move,{x,2},{x,0}}.
    {call_only,2,{f,2}}. % loop/2


{function, module_info, 0, 5}.
  {label,4}.
    {line,[]}.
    {func_info,{atom,i_ex_g},{atom,module_info},0}.
  {label,5}.
    {move,{atom,i_ex_g},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,i_ex_g},{atom,module_info},1}.
  {label,7}.
    {move,{x,0},{x,1}}.
    {move,{atom,i_ex_g},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
