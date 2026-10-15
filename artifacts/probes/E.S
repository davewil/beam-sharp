{module, 'E'}.  %% version = 0

{exports, [{'Inner',1},
           {'OuterExp',1},
           {'OuterPriv',1},
           {bs@type_atoms,0},
           {module_info,0},
           {module_info,1}]}.

{attributes, []}.

{labels, 17}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,'E'},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,nil,{x,0}}.
    return.


{function, 'Inner', 1, 4}.
  {label,3}.
    {line,[{location,"E/e.bs",5}]}.
    {func_info,{atom,'E'},{atom,'Inner'},1}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.
    return.


{function, 'OuterExp', 1, 6}.
  {label,5}.
    {line,[{location,"E/e.bs",9}]}.
    {func_info,{atom,'E'},{atom,'OuterExp'},1}.
  {label,6}.
    {test,is_nonempty_list,{f,7},[{x,0}]}.
    {get_hd,{x,0},{x,0}}.
    {call_only,1,{f,4}}. % 'Inner'/1
  {label,7}.
    {test,is_nil,{f,5},[{x,0}]}.
    {move,{integer,0},{x,0}}.
    return.


{function, 'InnerP', 1, 9}.
  {label,8}.
    {line,[{location,"E/e.bs",14}]}.
    {func_info,{atom,'E'},{atom,'InnerP'},1}.
  {label,9}.
    return.


{function, 'OuterPriv', 1, 11}.
  {label,10}.
    {line,[{location,"E/e.bs",17}]}.
    {func_info,{atom,'E'},{atom,'OuterPriv'},1}.
  {label,11}.
    {test,is_nonempty_list,{f,12},[{x,0}]}.
    {get_hd,{x,0},{x,0}}.
    {call_only,1,{f,9}}. % 'InnerP'/1
  {label,12}.
    {test,is_nil,{f,10},[{x,0}]}.
    {move,{integer,0},{x,0}}.
    return.


{function, module_info, 0, 14}.
  {label,13}.
    {line,[]}.
    {func_info,{atom,'E'},{atom,module_info},0}.
  {label,14}.
    {move,{atom,'E'},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 16}.
  {label,15}.
    {line,[]}.
    {func_info,{atom,'E'},{atom,module_info},1}.
  {label,16}.
    {move,{x,0},{x,1}}.
    {move,{atom,'E'},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
