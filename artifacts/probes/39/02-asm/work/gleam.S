{module, bench_gleam}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{part_two,1}]}.

{attributes, []}.

{labels, 19}.


{function, spin, 4, 2}.
  {label,1}.
    {line,[{location,"src/bench_gleam.gleam",14}]}.
    {func_info,{atom,bench_gleam},{atom,spin},4}.
  {label,2}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_eq_exact,{f,3},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,3}.
    {line,[{location,"src/bench_gleam.gleam",20}]}.
    {gc_bif,'+',
            {f,0},
            4,
            [{tr,{x,0},{t_integer,{-99,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {line,[{location,"src/bench_gleam.gleam",4}]}.
    {gc_bif,'rem',
            {f,0},
            4,
            [{tr,{x,0},{t_integer,{-100,100}}},{integer,100}],
            {x,0}}.
    {gc_bif,'+',{f,0},4,[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}],{x,0}}.
    {gc_bif,'rem',
            {f,0},
            4,
            [{tr,{x,0},{t_integer,{1,199}}},{integer,100}],
            {x,0}}.
    {line,[{location,"src/bench_gleam.gleam",21}]}.
    {gc_bif,'-',{f,0},4,[{x,2},{integer,1}],{x,2}}.
    {test,is_eq_exact,{f,4},[{tr,{x,0},{t_integer,{0,99}}},{integer,0}]}.
    {move,{integer,1},{x,4}}.
    {jump,{f,5}}.
  {label,4}.
    {move,{integer,0},{x,4}}.
  {label,5}.
    {gc_bif,'+',
            {f,0},
            5,
            [{tr,{x,3},{t_integer,{0,'+inf'}}},{tr,{x,4},{t_integer,{0,1}}}],
            {x,3}}.
    {call_only,4,{f,2}}. % spin/4


{function, clicks, 3, 7}.
  {label,6}.
    {line,[{location,"src/bench_gleam.gleam",38}]}.
    {func_info,{atom,bench_gleam},{atom,clicks},3}.
  {label,7}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_nonempty_list,{f,11},[{x,0}]}.
    {allocate,1,3}.
    {get_list,{x,0},{x,0},{y,0}}.
    {test,is_lt,{f,8},[{x,0},{integer,0}]}.
    {move,{integer,-1},{x,3}}.
    {jump,{f,9}}.
  {label,8}.
    {move,{integer,1},{x,3}}.
  {label,9}.
    {test,is_lt,{f,10},[{x,0},{integer,0}]}.
    {line,[{location,"src/bench_gleam.gleam",34}]}.
    {gc_bif,'-',{f,0},4,[{tr,{x,0},{t_number,{'-inf',0}}}],{x,0}}.
  {label,10}.
    {swap,{x,3},{x,1}}.
    {swap,{x,2},{x,3}}.
    {swap,{x,0},{x,2}}.
    {line,[{location,"src/bench_gleam.gleam",44}]}.
    {call,4,{f,2}}. % spin/4
    {'%',{var_info,{x,0},
                   [{type,{t_tuple,2,true,
                                   #{1 => {t_integer,{-99,99}},
                                     2 => {t_integer,{0,'+inf'}}}}}]}}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,7},1}. % clicks/3
  {label,11}.
    {test,is_nil,{f,12},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.
  {label,12}.
    {line,[{location,"src/bench_gleam.gleam",39}]}.
    {case_end,{x,0}}.


{function, part_two, 1, 14}.
  {label,13}.
    {line,[{location,"src/bench_gleam.gleam",48}]}.
    {func_info,{atom,bench_gleam},{atom,part_two},1}.
  {label,14}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,7}}. % clicks/3


{function, module_info, 0, 16}.
  {label,15}.
    {line,[]}.
    {func_info,{atom,bench_gleam},{atom,module_info},0}.
  {label,16}.
    {move,{atom,bench_gleam},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 18}.
  {label,17}.
    {line,[]}.
    {func_info,{atom,bench_gleam},{atom,module_info},1}.
  {label,18}.
    {move,{x,0},{x,1}}.
    {move,{atom,bench_gleam},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
