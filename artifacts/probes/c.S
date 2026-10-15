{module, c}.  %% version = 0

{exports, [{inner,1},{module_info,0},{module_info,1},{outer,1}]}.

{attributes, []}.

{labels, 9}.


{function, inner, 1, 2}.
  {label,1}.
    {line,[{location,"c.erl",3}]}.
    {func_info,{atom,c},{atom,inner},1}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.
    return.


{function, outer, 1, 4}.
  {label,3}.
    {line,[{location,"c.erl",4}]}.
    {func_info,{atom,c},{atom,outer},1}.
  {label,4}.
    {test,is_nonempty_list,{f,3},[{x,0}]}.
    {get_hd,{x,0},{x,0}}.
    {call_only,1,{f,2}}. % inner/1


{function, module_info, 0, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,c},{atom,module_info},0}.
  {label,6}.
    {move,{atom,c},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,c},{atom,module_info},1}.
  {label,8}.
    {move,{x,0},{x,1}}.
    {move,{atom,c},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
