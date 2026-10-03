{module, a1_true_fact}.  %% version = 0

{exports, [{'PartTwo',1},{bs@type_atoms,0},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 26}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,a1_true_fact},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,nil,{x,0}}.
    return.


{function, 'Wrap', 1, 4}.
  {label,3}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",12}]}.
    {func_info,{atom,a1_true_fact},{atom,'Wrap'},1}.
  {label,4}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}],{x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{1,199}}},{integer,100}],
            {x,0}}.
    return.


{function, 'Hit', 1, 6}.
  {label,5}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",15}]}.
    {func_info,{atom,a1_true_fact},{atom,'Hit'},1}.
  {label,6}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {test,is_eq_exact,{f,7},[{tr,{x,0},{t_integer,{-99,99}}},{integer,0}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,7}.
    {move,{integer,0},{x,0}}.
    return.


{function, 'Spin', 4, 9}.
  {label,8}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",19}]}.
    {func_info,{atom,b0_bs_as_is},{atom,'Spin'},4}.
  {label,9}.
    {'%',{var_info,{x,0},[{type,{t_integer,{0,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_eq_exact,{f,10},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,10}.
    {allocate,4,4}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,3},{y,1}}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",21}]}.
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-99,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {call,1,{f,4}}. % 'Wrap'/1
    {'%',{var_info,{x,0},[{type,{t_integer,{0,99}}}]}}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",22}]}.
    {gc_bif,'-',{f,0},1,[{y,2},{integer,1}],{y,2}}.
    {move,{x,0},{y,0}}.
    {call,1,{f,6}}. % 'Hit'/1
    {'%',{var_info,{x,0},[{type,{t_integer,{0,1}}}]}}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{y,1},{t_integer,{0,'+inf'}}},{tr,{x,0},{t_integer,{0,1}}}],
            {x,3}}.
    {move,{y,2},{x,2}}.
    {move,{y,3},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,4,{f,9},4}. % 'Spin'/4


{function, 'Sign', 1, 12}.
  {label,11}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",25}]}.
    {func_info,{atom,b0_bs_as_is},{atom,'Sign'},1}.
  {label,12}.
    {test,is_lt,{f,13},[{x,0},{integer,0}]}.
    {move,{integer,-1},{x,0}}.
    return.
  {label,13}.
    {move,{integer,1},{x,0}}.
    return.


{function, 'Size', 1, 15}.
  {label,14}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",29}]}.
    {func_info,{atom,b0_bs_as_is},{atom,'Size'},1}.
  {label,15}.
    {test,is_lt,{f,16},[{x,0},{integer,0}]}.
    {gc_bif,'-',{f,0},1,[{tr,{x,0},{t_number,{'-inf',0}}}],{x,0}}.
    return.
  {label,16}.
    return.


{function, 'Clicks', 3, 18}.
  {label,17}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",33}]}.
    {func_info,{atom,b0_bs_as_is},{atom,'Clicks'},3}.
  {label,18}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_nonempty_list,{f,19},[{x,0}]}.
    {allocate,4,3}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {get_list,{x,0},{y,1},{y,0}}.
    {move,{y,1},{x,0}}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",35}]}.
    {call,1,{f,12}}. % 'Sign'/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-1,1}}}]}}.
    {swap,{y,1},{x,0}}.
    {call,1,{f,15}}. % 'Size'/1
    {move,{x,0},{x,2}}.
    {move,{y,1},{x,1}}.
    {move,{y,2},{x,3}}.
    {move,{y,3},{x,0}}.
    {move,{y,0},{y,3}}.
    {trim,3,1}.
    {call,4,{f,9}}. % 'Spin'/4
    {'%',{var_info,{x,0},
                   [{type,{t_tuple,2,true,
                                   #{1 => {t_integer,{-99,99}},
                                     2 => {t_integer,{0,'+inf'}}}}}]}}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,18},1}. % 'Clicks'/3
  {label,19}.
    {test,is_nil,{f,17},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.


{function, 'PartTwo', 1, 21}.
  {label,20}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",39}]}.
    {func_info,{atom,b0_bs_as_is},{atom,'PartTwo'},1}.
  {label,21}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,18}}. % 'Clicks'/3


{function, module_info, 0, 23}.
  {label,22}.
    {line,[]}.
    {func_info,{atom,b0_bs_as_is},{atom,module_info},0}.
  {label,23}.
    {move,{atom,b0_bs_as_is},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 25}.
  {label,24}.
    {line,[]}.
    {func_info,{atom,b0_bs_as_is},{atom,module_info},1}.
  {label,25}.
    {move,{x,0},{x,1}}.
    {move,{atom,b0_bs_as_is},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
