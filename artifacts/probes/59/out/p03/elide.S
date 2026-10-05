{module, elide}.  %% version = 0

{exports, [{ex_caller,1},
           {ex_f,1},
           {lo_caller,1},
           {module_info,0},
           {module_info,1},
           {tag_caller,1},
           {un_caller,1}]}.

{attributes, []}.

{labels, 21}.


{function, ex_f, 1, 2}.
  {label,1}.
    {line,[{location,"src/elide.erl",7}]}.
    {func_info,{atom,elide},{atom,ex_f},1}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, ex_caller, 1, 4}.
  {label,3}.
    {line,[{location,"src/elide.erl",8}]}.
    {func_info,{atom,elide},{atom,ex_caller},1}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.
    {call_only,1,{f,2}}. % ex_f/1


{function, lo_f, 1, 6}.
  {label,5}.
    {line,[{location,"src/elide.erl",11}]}.
    {func_info,{atom,elide},{atom,lo_f},1}.
  {label,6}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, lo_caller, 1, 8}.
  {label,7}.
    {line,[{location,"src/elide.erl",12}]}.
    {func_info,{atom,elide},{atom,lo_caller},1}.
  {label,8}.
    {test,is_integer,{f,7},[{x,0}]}.
    {call_only,1,{f,6}}. % lo_f/1


{function, un_f, 1, 10}.
  {label,9}.
    {line,[{location,"src/elide.erl",15}]}.
    {func_info,{atom,elide},{atom,un_f},1}.
  {label,10}.
    {test,is_integer,{f,9},[{x,0}]}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.
    return.


{function, un_caller, 1, 12}.
  {label,11}.
    {line,[{location,"src/elide.erl",16}]}.
    {func_info,{atom,elide},{atom,un_caller},1}.
  {label,12}.
    {call_only,1,{f,10}}. % un_f/1


{function, tag_f, 1, 14}.
  {label,13}.
    {line,[{location,"src/elide.erl",19}]}.
    {func_info,{atom,elide},{atom,tag_f},1}.
  {label,14}.
    {'%',{var_info,{x,0},[{type,{t_map,any,any}}]}}.
    {bif,map_get,{f,13},[{atom,'Kind'},{tr,{x,0},{t_map,any,any}}],{x,1}}.
    {test,is_eq_exact,{f,13},[{x,1},{atom,'Order'}]}.
    {bif,map_get,{f,0},[{atom,'Total'},{tr,{x,0},{t_map,any,any}}],{x,0}}.
    return.


{function, tag_caller, 1, 16}.
  {label,15}.
    {line,[{location,"src/elide.erl",20}]}.
    {func_info,{atom,elide},{atom,tag_caller},1}.
  {label,16}.
    {bif,map_get,{f,15},[{atom,'Kind'},{x,0}],{x,1}}.
    {test,is_eq_exact,{f,15},[{x,1},{atom,'Order'}]}.
    {call_only,1,{f,14}}. % tag_f/1


{function, module_info, 0, 18}.
  {label,17}.
    {line,[]}.
    {func_info,{atom,elide},{atom,module_info},0}.
  {label,18}.
    {move,{atom,elide},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 20}.
  {label,19}.
    {line,[]}.
    {func_info,{atom,elide},{atom,module_info},1}.
  {label,20}.
    {move,{x,0},{x,1}}.
    {move,{atom,elide},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
