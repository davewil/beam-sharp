{module, ranges}.  %% version = 0

{exports, [{f_band,1},
           {f_case,1},
           {f_eq,1},
           {f_guard,1},
           {f_guard_chain,1},
           {f_plain,1},
           {f_rem,1},
           {f_ret,1},
           {f_spec,1},
           {module_info,0},
           {module_info,1}]}.

{attributes, []}.

{labels, 32}.


{function, f_plain, 1, 2}.
  {label,1}.
    {line,[{location,"ranges.erl",4}]}.
    {func_info,{atom,ranges},{atom,f_plain},1}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, f_spec, 1, 4}.
  {label,3}.
    {line,[{location,"ranges.erl",6}]}.
    {func_info,{atom,ranges},{atom,f_spec},1}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, f_guard, 1, 6}.
  {label,5}.
    {line,[{location,"ranges.erl",7}]}.
    {func_info,{atom,ranges},{atom,f_guard},1}.
  {label,6}.
    {test,is_integer,{f,5},[{x,0}]}.
    {test,is_ge,{f,5},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {test,is_ge,{f,5},[{integer,99},{tr,{x,0},{t_integer,any}}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, f_guard_chain, 1, 8}.
  {label,7}.
    {line,[{location,"ranges.erl",8}]}.
    {func_info,{atom,ranges},{atom,f_guard_chain},1}.
  {label,8}.
    {test,is_integer,{f,7},[{x,0}]}.
    {test,is_ge,{f,9},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {test,is_ge,{f,9},[{integer,99},{tr,{x,0},{t_integer,any}}]}.
    {line,[{location,"ranges.erl",9}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.
  {label,9}.
    {move,{atom,error},{x,0}}.
    return.


{function, f_band, 1, 11}.
  {label,10}.
    {line,[{location,"ranges.erl",10}]}.
    {func_info,{atom,ranges},{atom,f_band},1}.
  {label,11}.
    {test,is_integer,{f,10},[{x,0}]}.
    {gc_bif,'band',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,127}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{0,127}}},{integer,1}],{x,0}}.
    return.


{function, f_rem, 1, 13}.
  {label,12}.
    {line,[{location,"ranges.erl",11}]}.
    {func_info,{atom,ranges},{atom,f_rem},1}.
  {label,13}.
    {test,is_integer,{f,12},[{x,0}]}.
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,1}],{x,0}}.
    return.


{function, f_eq, 1, 15}.
  {label,14}.
    {line,[{location,"ranges.erl",12}]}.
    {func_info,{atom,ranges},{atom,f_eq},1}.
  {label,15}.
    {select_val,{x,0},{f,14},{list,[{integer,3},{f,16},{integer,4},{f,16}]}}.
  {label,16}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{3,4}}},{integer,1}],{x,0}}.
    return.


{function, f_case, 1, 18}.
  {label,17}.
    {line,[{location,"ranges.erl",13}]}.
    {func_info,{atom,ranges},{atom,f_case},1}.
  {label,18}.
    {test,is_integer,{f,17},[{x,0}]}.
    {select_val,{x,0},
                {f,22},
                {list,[{integer,0},
                       {f,21},
                       {integer,1},
                       {f,20},
                       {integer,2},
                       {f,19}]}}.
  {label,19}.
    {move,{integer,3},{x,0}}.
    return.
  {label,20}.
    {move,{integer,2},{x,0}}.
    return.
  {label,21}.
    {move,{integer,1},{x,0}}.
    return.
  {label,22}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, f_ret, 1, 24}.
  {label,23}.
    {line,[{location,"ranges.erl",15}]}.
    {func_info,{atom,ranges},{atom,f_ret},1}.
  {label,24}.
    {test,is_integer,{f,23},[{x,0}]}.
    {allocate,0,1}.
    {line,[{location,"ranges.erl",16}]}.
    {call,1,{f,27}}. % hidden/1
    {'%',{var_info,{x,0},[{type,number}]}}.
    {test,is_integer,{f,25},[{tr,{x,0},number}]}.
    {test,is_ge,{f,25},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {test,is_ge,{f,25},[{integer,99},{tr,{x,0},{t_integer,any}}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    {deallocate,0}.
    return.
  {label,25}.
    {case_end,{x,0}}.


{function, hidden, 1, 27}.
  {label,26}.
    {line,[{location,"ranges.erl",17}]}.
    {func_info,{atom,ranges},{atom,hidden},1}.
  {label,27}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {allocate,0,1}.
    {call_ext,1,{extfunc,erlang,phash2,1}}.
    {gc_bif,'-',{f,0},1,[{x,0},{integer,5}],{x,0}}.
    {deallocate,0}.
    return.


{function, module_info, 0, 29}.
  {label,28}.
    {line,[]}.
    {func_info,{atom,ranges},{atom,module_info},0}.
  {label,29}.
    {move,{atom,ranges},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 31}.
  {label,30}.
    {line,[]}.
    {func_info,{atom,ranges},{atom,module_info},1}.
  {label,31}.
    {move,{x,0},{x,1}}.
    {move,{atom,ranges},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
