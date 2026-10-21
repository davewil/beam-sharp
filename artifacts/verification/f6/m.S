{module, m}.  %% version = 0

{exports, [{loop,3},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 10}.


{function, f1, 1, 2}.
  {label,1}.
    {line,[{location,[],3}]}.
    {func_info,{atom,m},{atom,f1},1}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.
    {test,is_ge,{f,1},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {test,is_ge,{f,1},[{integer,255},{tr,{x,0},{t_integer,{0,'+inf'}}}]}.
    return.


{function, loop, 3, 4}.
  {label,3}.
    {line,[{location,[],4}]}.
    {func_info,{atom,m},{atom,loop},3}.
  {label,4}.
    {test,is_eq_exact,{f,5},[{x,0},{integer,0}]}.
    {move,{x,2},{x,0}}.
    return.
  {label,5}.
    {line,[{location,[],5}]}.
    {gc_bif,'-',{f,0},3,[{x,0},{integer,1}],{x,0}}.
    {allocate,3,3}.
    {move,{x,0},{y,0}}.
    {move,{x,2},{y,1}}.
    {move,{x,1},{y,2}}.
    {move,{x,1},{x,0}}.
    {call,1,{f,2}}. % f1/1
    {'%',{var_info,{x,0},[{type,{t_integer,{0,255}}}]}}.
    {gc_bif,'+',{f,0},1,[{y,1},{tr,{x,0},{t_integer,{0,255}}}],{x,2}}.
    {move,{y,2},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,4},3}. % loop/3


{function, module_info, 0, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,m},{atom,module_info},0}.
  {label,7}.
    {move,{atom,m},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 9}.
  {label,8}.
    {line,[]}.
    {func_info,{atom,m},{atom,module_info},1}.
  {label,9}.
    {move,{x,0},{x,1}}.
    {move,{atom,m},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
