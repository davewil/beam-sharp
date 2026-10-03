{module, e2_erlang_inline}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{part_two,1}]}.

{attributes, []}.

{labels, 22}.


{function, spin, 4, 2}.
  {label,1}.
    {line,[{location,"../../../../aoc/bench/bench_erl.erl",9}]}.
    {func_info,{atom,e2_erlang_inline},{atom,spin},4}.
  {label,2}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_eq_exact,{f,3},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,3}.
    {line,[{location,"../../../../aoc/bench/bench_erl.erl",11}]}.
    {gc_bif,'+',
            {f,0},
            4,
            [{tr,{x,0},{t_integer,{-99,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {line,[{location,"../../../../aoc/bench/bench_erl.erl",4}]}.
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
    {line,[{location,"../../../../aoc/bench/bench_erl.erl",12}]}.
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
    {line,[{location,"../../../../aoc/bench/bench_erl.erl",21}]}.
    {func_info,{atom,e2_erlang_inline},{atom,clicks},3}.
  {label,7}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_nonempty_list,{f,13},[{x,0}]}.
    {allocate,1,3}.
    {get_list,{x,0},{x,0},{y,0}}.
    {test,is_ne_exact,{f,8},[{x,0},{integer,0}]}.
    {test,is_lt,{f,9},[{integer,0},{x,0}]}.
  {label,8}.
    {move,{integer,1},{x,3}}.
    {jump,{f,10}}.
  {label,9}.
    {test,is_lt,{f,12},[{tr,{x,0},{t_number,{'-inf',0}}},{integer,0}]}.
    {move,{integer,-1},{x,3}}.
  {label,10}.
    {test,is_lt,{f,11},[{x,0},{integer,0}]}.
    {line,[{location,"../../../../aoc/bench/bench_erl.erl",19}]}.
    {gc_bif,'-',{f,0},4,[{tr,{x,0},{t_number,{'-inf',0}}}],{x,0}}.
  {label,11}.
    {swap,{x,3},{x,1}}.
    {swap,{x,2},{x,3}}.
    {swap,{x,0},{x,2}}.
    {line,[{location,"../../../../aoc/bench/bench_erl.erl",23}]}.
    {call,4,{f,2}}. % spin/4
    {'%',{var_info,{x,0},
                   [{type,{t_tuple,2,true,
                                   #{1 => {t_integer,{-99,99}},
                                     2 => {t_integer,{0,'+inf'}}}}}]}}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,7},1}. % clicks/3
  {label,12}.
    {call_last,1,{f,21},1}. % '-inlined-sign/1-'/1
  {label,13}.
    {test,is_nil,{f,6},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.


{function, part_two, 1, 15}.
  {label,14}.
    {line,[{location,"../../../../aoc/bench/bench_erl.erl",26}]}.
    {func_info,{atom,e2_erlang_inline},{atom,part_two},1}.
  {label,15}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,7}}. % clicks/3


{function, module_info, 0, 17}.
  {label,16}.
    {line,[]}.
    {func_info,{atom,e2_erlang_inline},{atom,module_info},0}.
  {label,17}.
    {move,{atom,e2_erlang_inline},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 19}.
  {label,18}.
    {line,[]}.
    {func_info,{atom,e2_erlang_inline},{atom,module_info},1}.
  {label,19}.
    {move,{x,0},{x,1}}.
    {move,{atom,e2_erlang_inline},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.


{function, '-inlined-sign/1-', 1, 21}.
  {label,20}.
    {line,[{location,"../../../../aoc/bench/bench_erl.erl",14}]}.
    {func_info,{atom,e2_erlang_inline},{atom,'-inlined-sign/1-'},1}.
  {label,21}.
    {jump,{f,20}}.
