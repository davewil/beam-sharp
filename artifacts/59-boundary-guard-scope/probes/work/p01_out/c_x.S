{module, c_x}.  %% version = 0

{exports, [{esc,0},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 9}.


{function, p, 1, 2}.
  {label,1}.
    {line,[{location,"c_x.erl",3}]}.
    {func_info,{atom,c_x},{atom,p},1}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, esc, 0, 4}.
  {label,3}.
    {line,[{location,"c_x.erl",4}]}.
    {func_info,{atom,c_x},{atom,esc},0}.
  {label,4}.
    {test_heap,{alloc,[{words,0},{floats,0},{funs,1}]},0}.
    {make_fun3,{f,2},0,0,{x,0},{list,[]}}.
    {'%',{var_info,{x,0},[{fun_type,{t_integer,any}}]}}.
    return.


{function, module_info, 0, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,c_x},{atom,module_info},0}.
  {label,6}.
    {move,{atom,c_x},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,c_x},{atom,module_info},1}.
  {label,8}.
    {move,{x,0},{x,1}}.
    {move,{atom,c_x},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
