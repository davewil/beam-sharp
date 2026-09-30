{module, 'RefWrap'}.  %% version = 0

{exports, [{'Run',1},{bs@type_atoms,0},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 15}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,'RefWrap'},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,nil,{x,0}}.
    return.


{function, 'Clamp', 1, 4}.
  {label,3}.
    {line,[{location,"/home/user/beam-sharp/artifacts/39/probes/RefWrap/refwrap.bs",
                     8}]}.
    {func_info,{atom,'RefWrap'},{atom,'Clamp'},1}.
  {label,4}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {test,is_ge,{f,5},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {test,is_ge,{f,5},[{integer,99},{tr,{x,0},{t_integer,any}}]}.
    return.
  {label,5}.
    {move,{integer,0},{x,0}}.
    return.


{function, 'Bucket', 1, 7}.
  {label,6}.
    {line,[{location,"/home/user/beam-sharp/artifacts/39/probes/RefWrap/refwrap.bs",
                     12}]}.
    {func_info,{atom,'RefWrap'},{atom,'Bucket'},1}.
  {label,7}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {test,is_lt,{f,8},[{tr,{x,0},{t_integer,any}},{integer,50}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,8}.
    {move,{integer,2},{x,0}}.
    return.


{function, 'Run', 1, 10}.
  {label,9}.
    {line,[{location,"/home/user/beam-sharp/artifacts/39/probes/RefWrap/refwrap.bs",
                     16}]}.
    {func_info,{atom,'RefWrap'},{atom,'Run'},1}.
  {label,10}.
    {test,is_integer,{f,9},[{x,0}]}.
    {allocate,0,1}.
    {call,1,{f,4}}. % 'Clamp'/1
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {call_last,1,{f,7},0}. % 'Bucket'/1


{function, module_info, 0, 12}.
  {label,11}.
    {line,[]}.
    {func_info,{atom,'RefWrap'},{atom,module_info},0}.
  {label,12}.
    {move,{atom,'RefWrap'},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 14}.
  {label,13}.
    {line,[]}.
    {func_info,{atom,'RefWrap'},{atom,module_info},1}.
  {label,14}.
    {move,{x,0},{x,1}}.
    {move,{atom,'RefWrap'},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
