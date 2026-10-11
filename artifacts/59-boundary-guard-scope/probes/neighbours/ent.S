{module, ent}.  %% version = 0

{exports, [{module_info,0},
           {module_info,1},
           {pub,1},
           {via_known,1},
           {via_local,1},
           {via_pub,1}]}.

{attributes, []}.

{labels, 15}.


{function, pub, 1, 2}.
  {label,1}.
    {line,[{location,"ent.erl",4}]}.
    {func_info,{atom,ent},{atom,pub},1}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, loc, 1, 4}.
  {label,3}.
    {line,[{location,"ent.erl",5}]}.
    {func_info,{atom,ent},{atom,loc},1}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, via_local, 1, 6}.
  {label,5}.
    {line,[{location,"ent.erl",7}]}.
    {func_info,{atom,ent},{atom,via_local},1}.
  {label,6}.
    {bif,hd,{f,0},[{x,0}],{x,0}}.
    {call_only,1,{f,4}}. % loc/1


{function, via_known, 1, 8}.
  {label,7}.
    {line,[{location,"ent.erl",9}]}.
    {func_info,{atom,ent},{atom,via_known},1}.
  {label,8}.
    {gc_bif,length,{f,0},1,[{x,0}],{x,0}}.
    {call_only,1,{f,4}}. % loc/1


{function, via_pub, 1, 10}.
  {label,9}.
    {line,[{location,"ent.erl",11}]}.
    {func_info,{atom,ent},{atom,via_pub},1}.
  {label,10}.
    {bif,hd,{f,0},[{x,0}],{x,0}}.
    {call_only,1,{f,2}}. % pub/1


{function, module_info, 0, 12}.
  {label,11}.
    {line,[]}.
    {func_info,{atom,ent},{atom,module_info},0}.
  {label,12}.
    {move,{atom,ent},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 14}.
  {label,13}.
    {line,[]}.
    {func_info,{atom,ent},{atom,module_info},1}.
  {label,14}.
    {move,{x,0},{x,1}}.
    {move,{atom,ent},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
