{module, m_tag_none}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{pub,1}]}.

{attributes, []}.

{labels, 9}.


{function, pub, 1, 2}.
  {label,1}.
    {line,[{location,"/tmp/p3_12388/m_tag_none.erl",3}]}.
    {func_info,{atom,m_tag_none},{atom,pub},1}.
  {label,2}.
    {call_only,1,{f,4}}. % total/1


{function, total, 1, 4}.
  {label,3}.
    {line,[{location,"/tmp/p3_12388/m_tag_none.erl",4}]}.
    {func_info,{atom,m_tag_none},{atom,total},1}.
  {label,4}.
    {bif,map_get,{f,0},[{atom,total},{x,0}],{x,0}}.
    return.


{function, module_info, 0, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,m_tag_none},{atom,module_info},0}.
  {label,6}.
    {move,{atom,m_tag_none},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,m_tag_none},{atom,module_info},1}.
  {label,8}.
    {move,{x,0},{x,1}}.
    {move,{atom,m_tag_none},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
