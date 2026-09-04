{module, bench_erl}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{part_two,1}]}.

{attributes, []}.

{labels, 25}.


{function, wrap, 1, 2}.
  {label,1}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",4}]}.
    {func_info,{atom,bench_erl},{atom,wrap},1}.
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


{function, hit, 1, 4}.
  {label,3}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",6}]}.
    {func_info,{atom,bench_erl},{atom,hit},1}.
  {label,4}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {test,is_eq_exact,{f,5},[{tr,{x,0},{t_integer,{-99,99}}},{integer,0}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,5}.
    {move,{integer,0},{x,0}}.
    return.


{function, spin, 4, 7}.
  {label,6}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",9}]}.
    {func_info,{atom,bench_erl},{atom,spin},4}.
  {label,7}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,any}}]}}.
    {test,is_eq_exact,{f,8},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,8}.
    {allocate,4,4}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,3},{y,1}}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",11}]}.
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-99,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {call,1,{f,2}}. % wrap/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",12}]}.
    {gc_bif,'-',{f,0},1,[{y,2},{integer,1}],{y,2}}.
    {move,{x,0},{y,0}}.
    {call,1,{f,4}}. % hit/1
    {'%',{var_info,{x,0},[{type,{t_integer,{0,1}}}]}}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{y,1},{t_integer,any}},{tr,{x,0},{t_integer,{0,1}}}],
            {x,3}}.
    {move,{y,2},{x,2}}.
    {move,{y,3},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,4,{f,7},4}. % spin/4


{function, sign, 1, 10}.
  {label,9}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",14}]}.
    {func_info,{atom,bench_erl},{atom,sign},1}.
  {label,10}.
    {test,is_ne_exact,{f,11},[{x,0},{integer,0}]}.
    {test,is_lt,{f,12},[{integer,0},{x,0}]}.
  {label,11}.
    {move,{integer,1},{x,0}}.
    return.
  {label,12}.
    {test,is_lt,{f,9},[{x,0},{integer,0}]}.
    {move,{integer,-1},{x,0}}.
    return.


{function, size_, 1, 14}.
  {label,13}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",18}]}.
    {func_info,{atom,bench_erl},{atom,size_},1}.
  {label,14}.
    {test,is_ge,{f,15},[{x,0},{integer,0}]}.
    return.
  {label,15}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",19}]}.
    {gc_bif,'-',{f,0},1,[{x,0}],{x,0}}.
    return.


{function, clicks, 3, 17}.
  {label,16}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",21}]}.
    {func_info,{atom,bench_erl},{atom,clicks},3}.
  {label,17}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,any}}]}}.
    {test,is_nonempty_list,{f,18},[{x,0}]}.
    {allocate,4,3}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {get_list,{x,0},{y,1},{y,0}}.
    {move,{y,1},{x,0}}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",23}]}.
    {call,1,{f,10}}. % sign/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-1,1}}}]}}.
    {swap,{y,1},{x,0}}.
    {call,1,{f,14}}. % size_/1
    {move,{x,0},{x,2}}.
    {move,{y,1},{x,1}}.
    {move,{y,2},{x,3}}.
    {move,{y,3},{x,0}}.
    {move,{y,0},{y,3}}.
    {trim,3,1}.
    {call,4,{f,7}}. % spin/4
    {'%',{var_info,{x,0},
                   [{type,{t_tuple,2,true,
                                   #{1 => {t_integer,{-99,99}},
                                     2 => {t_integer,any}}}}]}}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,17},1}. % clicks/3
  {label,18}.
    {test,is_nil,{f,16},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.


{function, part_two, 1, 20}.
  {label,19}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_erl.erl",26}]}.
    {func_info,{atom,bench_erl},{atom,part_two},1}.
  {label,20}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,17}}. % clicks/3


{function, module_info, 0, 22}.
  {label,21}.
    {line,[]}.
    {func_info,{atom,bench_erl},{atom,module_info},0}.
  {label,22}.
    {move,{atom,bench_erl},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 24}.
  {label,23}.
    {line,[]}.
    {func_info,{atom,bench_erl},{atom,module_info},1}.
  {label,24}.
    {move,{x,0},{x,1}}.
    {move,{atom,bench_erl},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
