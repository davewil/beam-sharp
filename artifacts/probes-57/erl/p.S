{module, p}.  %% version = 0

{exports, [{f,1},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 10}.


{function, f, 1, 2}.
  {label,1}.
    {line,[{location,"p.erl",3}]}.
    {func_info,{atom,p},{atom,f},1}.
  {label,2}.
    {select_val,{x,0},{f,5},{list,[{integer,-5},{f,4},{integer,3},{f,3}]}}.
  {label,3}.
    {move,{atom,c},{x,0}}.
    return.
  {label,4}.
    {move,{atom,a},{x,0}}.
    return.
  {label,5}.
    {move,{atom,b},{x,0}}.
    return.


{function, module_info, 0, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,p},{atom,module_info},0}.
  {label,7}.
    {move,{atom,p},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 9}.
  {label,8}.
    {line,[]}.
    {func_info,{atom,p},{atom,module_info},1}.
  {label,9}.
    {move,{x,0},{x,1}}.
    {move,{atom,p},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
