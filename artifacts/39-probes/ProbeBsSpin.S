{module, 'ProbeBsSpin'}.  %% version = 0

{exports, [{'SpinOnly',2},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 15}.


{function, 'Wrap', 1, 2}.
  {label,1}.
    {line,[{location,"/home/user/beam-sharp/artifacts/39-probes/ProbeBsSpin/probe_spin.bs",
                     10}]}.
    {func_info,{atom,'ProbeBsSpin'},{atom,'Wrap'},1}.
  {label,2}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}],{x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{1,199}}},{integer,100}],
            {x,0}}.
    return.


{function, 'Hit', 1, 4}.
  {label,3}.
    {line,[{location,"/home/user/beam-sharp/artifacts/39-probes/ProbeBsSpin/probe_spin.bs",
                     13}]}.
    {func_info,{atom,'ProbeBsSpin'},{atom,'Hit'},1}.
  {label,4}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {test,is_eq_exact,{f,5},[{tr,{x,0},{t_integer,{-99,99}}},{integer,0}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,5}.
    {move,{integer,0},{x,0}}.
    return.


{function, 'Spin', 4, 7}.
  {label,6}.
    {line,[{location,"/home/user/beam-sharp/artifacts/39-probes/ProbeBsSpin/probe_spin.bs",
                     17}]}.
    {func_info,{atom,'ProbeBsSpin'},{atom,'Spin'},4}.
  {label,7}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,any}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,any}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,any}}]}}.
    {test,is_eq_exact,{f,8},[{tr,{x,2},{t_integer,any}},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,8}.
    {line,[{location,"/home/user/beam-sharp/artifacts/39-probes/ProbeBsSpin/probe_spin.bs",
                     19}]}.
    {gc_bif,'+',
            {f,0},
            4,
            [{tr,{x,0},{t_integer,{-99,99}}},{tr,{x,1},{t_integer,any}}],
            {x,0}}.
    {allocate,4,4}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,3},{y,1}}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {call,1,{f,2}}. % 'Wrap'/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {line,[{location,"/home/user/beam-sharp/artifacts/39-probes/ProbeBsSpin/probe_spin.bs",
                     20}]}.
    {gc_bif,'-',{f,0},1,[{tr,{y,2},{t_integer,any}},{integer,1}],{y,2}}.
    {move,{x,0},{y,0}}.
    {call,1,{f,4}}. % 'Hit'/1
    {'%',{var_info,{x,0},[{type,{t_integer,{0,1}}}]}}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{y,1},{t_integer,any}},{tr,{x,0},{t_integer,{0,1}}}],
            {x,3}}.
    {move,{y,2},{x,2}}.
    {move,{y,3},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,4,{f,7},4}. % 'Spin'/4


{function, 'SpinOnly', 2, 10}.
  {label,9}.
    {line,[{location,"/home/user/beam-sharp/artifacts/39-probes/ProbeBsSpin/probe_spin.bs",
                     23}]}.
    {func_info,{atom,'ProbeBsSpin'},{atom,'SpinOnly'},2}.
  {label,10}.
    {test,is_integer,{f,9},[{x,0}]}.
    {test,is_integer,{f,9},[{x,1}]}.
    {move,{x,1},{x,2}}.
    {move,{x,0},{x,1}}.
    {move,{integer,0},{x,3}}.
    {move,{integer,50},{x,0}}.
    {call_only,4,{f,7}}. % 'Spin'/4


{function, module_info, 0, 12}.
  {label,11}.
    {line,[]}.
    {func_info,{atom,'ProbeBsSpin'},{atom,module_info},0}.
  {label,12}.
    {move,{atom,'ProbeBsSpin'},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 14}.
  {label,13}.
    {line,[]}.
    {func_info,{atom,'ProbeBsSpin'},{atom,module_info},1}.
  {label,14}.
    {move,{x,0},{x,1}}.
    {move,{atom,'ProbeBsSpin'},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
