{module, m_int_guard}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{pub,1}]}.

{attributes, []}.

{labels, 10}.


{function, pub, 1, 2}.
  {label,1}.
    {line,[{location,"/tmp/p3_12388/m_int_guard.erl",3}]}.
    {func_info,{atom,m_int_guard},{atom,pub},1}.
  {label,2}.
    {call_only,1,{f,4}}. % total/1


{function, total, 1, 4}.
  {label,3}.
    {line,[{location,"/tmp/p3_12388/m_int_guard.erl",4}]}.
    {func_info,{atom,m_int_guard},{atom,total},1}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.
    {test,is_ge,{f,5},[{tr,{x,0},{t_integer,any}},{integer,9}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,5}.
    {test,is_ge,{f,3},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {test,is_ge,{f,3},[{integer,8},{tr,{x,0},{t_integer,any}}]}.
    {move,{integer,0},{x,0}}.
    return.


{function, module_info, 0, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,m_int_guard},{atom,module_info},0}.
  {label,7}.
    {move,{atom,m_int_guard},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 9}.
  {label,8}.
    {line,[]}.
    {func_info,{atom,m_int_guard},{atom,module_info},1}.
  {label,9}.
    {move,{x,0},{x,1}}.
    {move,{atom,m_int_guard},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
