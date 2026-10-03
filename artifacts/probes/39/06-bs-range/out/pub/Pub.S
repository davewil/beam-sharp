{module, 'Pub'}.  %% version = 0

{exports, [{'Plain',1},
           {'Twice',1},
           {bs@type_atoms,0},
           {module_info,0},
           {module_info,1}]}.

{attributes, []}.

{labels, 11}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,'Pub'},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,nil,{x,0}}.
    return.


{function, 'Twice', 1, 4}.
  {label,3}.
    {line,[{location,"Pub/pub.bs",7}]}.
    {func_info,{atom,'Pub'},{atom,'Twice'},1}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.
    {test,is_ge,{f,3},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {test,is_ge,{f,3},[{integer,99},{tr,{x,0},{t_integer,{0,'+inf'}}}]}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{0,99}}},{tr,{x,0},{t_integer,{0,99}}}],
            {x,0}}.
    return.


{function, 'Plain', 1, 6}.
  {label,5}.
    {line,[{location,"Pub/pub.bs",10}]}.
    {func_info,{atom,'Pub'},{atom,'Plain'},1}.
  {label,6}.
    {test,is_integer,{f,5},[{x,0}]}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,any}},{tr,{x,0},{t_integer,any}}],
            {x,0}}.
    return.


{function, module_info, 0, 8}.
  {label,7}.
    {line,[]}.
    {func_info,{atom,'Pub'},{atom,module_info},0}.
  {label,8}.
    {move,{atom,'Pub'},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 10}.
  {label,9}.
    {line,[]}.
    {func_info,{atom,'Pub'},{atom,module_info},1}.
  {label,10}.
    {move,{x,0},{x,1}}.
    {move,{atom,'Pub'},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
