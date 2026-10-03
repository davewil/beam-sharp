{module, b3_bs_inline}.  %% version = 0

{exports, [{'PartTwo',1},{bs@type_atoms,0},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 22}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,b3_bs_inline},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,nil,{x,0}}.
    return.


{function, 'Wrap', 1, 4}.
  {label,3}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",12}]}.
    {func_info,{atom,b3_bs_inline},{atom,'Wrap'},1}.
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


{function, 'Spin', 4, 6}.
  {label,5}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",19}]}.
    {func_info,{atom,b3_bs_inline},{atom,'Spin'},4}.
  {label,6}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_eq_exact,{f,7},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,7}.
    {allocate,3,4}.
    {move,{x,3},{y,0}}.
    {move,{x,2},{y,1}}.
    {move,{x,1},{y,2}}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",21}]}.
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-99,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {call,1,{f,4}}. % 'Wrap'/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",22}]}.
    {gc_bif,'-',{f,0},1,[{y,1},{integer,1}],{x,1}}.
    {test,is_eq_exact,{f,8},[{tr,{x,0},{t_integer,{-99,99}}},{integer,0}]}.
    {move,{integer,1},{x,2}}.
    {jump,{f,9}}.
  {label,8}.
    {move,{integer,0},{x,2}}.
  {label,9}.
    {gc_bif,'+',
            {f,0},
            3,
            [{tr,{y,0},{t_integer,{0,'+inf'}}},{tr,{x,2},{t_integer,{0,1}}}],
            {x,3}}.
    {move,{x,1},{x,2}}.
    {move,{y,2},{x,1}}.
    {call_last,4,{f,6},3}. % 'Spin'/4


{function, 'Clicks', 3, 11}.
  {label,10}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",33}]}.
    {func_info,{atom,b3_bs_inline},{atom,'Clicks'},3}.
  {label,11}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_nonempty_list,{f,15},[{x,0}]}.
    {allocate,1,3}.
    {get_list,{x,0},{x,0},{y,0}}.
    {test,is_lt,{f,12},[{x,0},{integer,0}]}.
    {move,{integer,-1},{x,3}}.
    {jump,{f,13}}.
  {label,12}.
    {move,{integer,1},{x,3}}.
  {label,13}.
    {test,is_lt,{f,14},[{x,0},{integer,0}]}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",29}]}.
    {gc_bif,'-',{f,0},4,[{tr,{x,0},{t_number,{'-inf',0}}}],{x,0}}.
  {label,14}.
    {swap,{x,3},{x,1}}.
    {swap,{x,2},{x,3}}.
    {swap,{x,0},{x,2}}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",35}]}.
    {call,4,{f,6}}. % 'Spin'/4
    {'%',{var_info,{x,0},
                   [{type,{t_tuple,2,true,
                                   #{1 => {t_integer,{-99,99}},
                                     2 => {t_integer,{0,'+inf'}}}}}]}}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,11},1}. % 'Clicks'/3
  {label,15}.
    {test,is_nil,{f,10},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.


{function, 'PartTwo', 1, 17}.
  {label,16}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",39}]}.
    {func_info,{atom,b3_bs_inline},{atom,'PartTwo'},1}.
  {label,17}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,11}}. % 'Clicks'/3


{function, module_info, 0, 19}.
  {label,18}.
    {line,[]}.
    {func_info,{atom,b3_bs_inline},{atom,module_info},0}.
  {label,19}.
    {move,{atom,b3_bs_inline},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 21}.
  {label,20}.
    {line,[]}.
    {func_info,{atom,b3_bs_inline},{atom,module_info},1}.
  {label,21}.
    {move,{x,0},{x,1}}.
    {move,{atom,b3_bs_inline},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
