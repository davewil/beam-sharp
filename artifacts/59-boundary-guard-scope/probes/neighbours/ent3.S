{module, ent3}.  %% version = 0

{exports, [{a,1},{b,1},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 13}.


{function, loc_known, 1, 2}.
  {label,1}.
    {line,[{location,"ent3.erl",4}]}.
    {func_info,{atom,ent3},{atom,loc_known},1}.
  {label,2}.
    {'%',{var_info,{x,0},[{type,{t_integer,{0,288230376151711743}}}]}}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{0,288230376151711743}}},{integer,1}],
            {x,0}}.
    return.


{function, loc_unknown, 1, 4}.
  {label,3}.
    {line,[{location,"ent3.erl",5}]}.
    {func_info,{atom,ent3},{atom,loc_unknown},1}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, a, 1, 6}.
  {label,5}.
    {line,[{location,"ent3.erl",6}]}.
    {func_info,{atom,ent3},{atom,a},1}.
  {label,6}.
    {gc_bif,length,{f,0},1,[{x,0}],{x,0}}.
    {call_only,1,{f,2}}. % loc_known/1


{function, b, 1, 8}.
  {label,7}.
    {line,[{location,"ent3.erl",7}]}.
    {func_info,{atom,ent3},{atom,b},1}.
  {label,8}.
    {bif,hd,{f,0},[{x,0}],{x,0}}.
    {call_only,1,{f,4}}. % loc_unknown/1


{function, module_info, 0, 10}.
  {label,9}.
    {line,[]}.
    {func_info,{atom,ent3},{atom,module_info},0}.
  {label,10}.
    {move,{atom,ent3},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 12}.
  {label,11}.
    {line,[]}.
    {func_info,{atom,ent3},{atom,module_info},1}.
  {label,12}.
    {move,{x,0},{x,1}}.
    {move,{atom,ent3},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
