{module, m}.  %% version = 0

{exports, [{f,1},{g,1},{h,1},{k,1},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 17}.


{function, f, 1, 2}.
  {label,1}.
    {line,[{location,[],1}]}.
    {func_info,{atom,m},{atom,f},1}.
  {label,2}.
    {test,is_ge,{f,3},[{x,0},{integer,-5}]}.
    {move,{atom,ok},{x,0}}.
    return.
  {label,3}.
    {move,{atom,no},{x,0}}.
    return.


{function, g, 1, 5}.
  {label,4}.
    {line,[{location,[],1}]}.
    {func_info,{atom,m},{atom,g},1}.
  {label,5}.
    {test,is_eq_exact,{f,6},[{x,0},{integer,-5}]}.
    {move,{atom,ok},{x,0}}.
    return.
  {label,6}.
    {move,{atom,no},{x,0}}.
    return.


{function, h, 1, 8}.
  {label,7}.
    {line,[{location,[],1}]}.
    {func_info,{atom,m},{atom,h},1}.
  {label,8}.
    {test,is_ge,{f,9},[{x,0},{integer,5}]}.
    {move,{atom,ok},{x,0}}.
    return.
  {label,9}.
    {move,{atom,no},{x,0}}.
    return.


{function, k, 1, 11}.
  {label,10}.
    {line,[{location,[],1}]}.
    {func_info,{atom,m},{atom,k},1}.
  {label,11}.
    {test,is_eq_exact,{f,12},[{x,0},{integer,5}]}.
    {move,{atom,ok},{x,0}}.
    return.
  {label,12}.
    {move,{atom,no},{x,0}}.
    return.


{function, module_info, 0, 14}.
  {label,13}.
    {line,[]}.
    {func_info,{atom,m},{atom,module_info},0}.
  {label,14}.
    {move,{atom,m},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 16}.
  {label,15}.
    {line,[]}.
    {func_info,{atom,m},{atom,module_info},1}.
  {label,16}.
    {move,{x,0},{x,1}}.
    {move,{atom,m},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
