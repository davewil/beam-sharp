{module, 'Elixir.BenchEx'}.  %% version = 0

{exports, [{'__info__',1},{module_info,0},{module_info,1},{part_two,1}]}.

{attributes, []}.

{labels, 36}.


{function, '__info__', 1, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,'__info__'},1}.
  {label,2}.
    {select_val,{x,0},
                {f,9},
                {list,[{atom,attributes},
                       {f,8},
                       {atom,compile},
                       {f,8},
                       {atom,deprecated},
                       {f,7},
                       {atom,exports_md5},
                       {f,6},
                       {atom,functions},
                       {f,5},
                       {atom,macros},
                       {f,7},
                       {atom,md5},
                       {f,8},
                       {atom,module},
                       {f,4},
                       {atom,struct},
                       {f,3}]}}.
  {label,3}.
    {move,{atom,nil},{x,0}}.
    return.
  {label,4}.
    {move,{atom,'Elixir.BenchEx'},{x,0}}.
    return.
  {label,5}.
    {move,{literal,[{part_two,1}]},{x,0}}.
    return.
  {label,6}.
    {move,{literal,<<43,99,90,30,32,180,26,118,184,26,213,222,207,91,65,50>>},
          {x,0}}.
    return.
  {label,7}.
    {move,nil,{x,0}}.
    return.
  {label,8}.
    {move,{x,0},{x,1}}.
    {move,{atom,'Elixir.BenchEx'},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
  {label,9}.
    {call_only,1,{f,35}}. % '-inlined-__info__/1-'/1


{function, clicks, 3, 11}.
  {label,10}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",21}]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,clicks},3}.
  {label,11}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_nonempty_list,{f,12},[{x,0}]}.
    {allocate,4,3}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {get_list,{x,0},{y,1},{y,0}}.
    {move,{y,1},{x,0}}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",24}]}.
    {call,1,{f,19}}. % sign/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-1,1}}}]}}.
    {swap,{y,1},{x,0}}.
    {call,1,{f,23}}. % size_/1
    {move,{x,0},{x,2}}.
    {move,{y,1},{x,1}}.
    {move,{y,2},{x,3}}.
    {move,{y,3},{x,0}}.
    {move,{y,0},{y,3}}.
    {trim,3,1}.
    {call,4,{f,26}}. % spin/4
    {'%',{var_info,{x,0},
                   [{type,{t_tuple,2,true,
                                   #{1 => {t_integer,{-99,99}},
                                     2 => {t_integer,{0,'+inf'}}}}}]}}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,11},1}. % clicks/3
  {label,12}.
    {test,is_nil,{f,10},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.


{function, hit, 1, 14}.
  {label,13}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",4}]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,hit},1}.
  {label,14}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {test,is_eq_exact,{f,15},[{tr,{x,0},{t_integer,{-99,99}}},{integer,0}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,15}.
    {move,{integer,0},{x,0}}.
    return.


{function, part_two, 1, 17}.
  {label,16}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",28}]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,part_two},1}.
  {label,17}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,11}}. % clicks/3


{function, sign, 1, 19}.
  {label,18}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",14}]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,sign},1}.
  {label,19}.
    {test,is_ne_exact,{f,20},[{x,0},{integer,0}]}.
    {test,is_lt,{f,21},[{integer,0},{x,0}]}.
  {label,20}.
    {move,{integer,1},{x,0}}.
    return.
  {label,21}.
    {test,is_lt,{f,18},[{tr,{x,0},{t_number,{'-inf',0}}},{integer,0}]}.
    {move,{integer,-1},{x,0}}.
    return.


{function, size_, 1, 23}.
  {label,22}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",18}]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,size_},1}.
  {label,23}.
    {test,is_ge,{f,24},[{x,0},{integer,0}]}.
    return.
  {label,24}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",19}]}.
    {gc_bif,'-',{f,0},1,[{tr,{x,0},{t_number,{'-inf',0}}}],{x,0}}.
    return.


{function, spin, 4, 26}.
  {label,25}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",7}]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,spin},4}.
  {label,26}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,{0,'+inf'}}}]}}.
    {test,is_eq_exact,{f,27},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,27}.
    {allocate,4,4}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,3},{y,1}}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",10}]}.
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-99,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {call,1,{f,29}}. % wrap/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",11}]}.
    {gc_bif,'-',{f,0},1,[{y,2},{integer,1}],{y,2}}.
    {move,{x,0},{y,0}}.
    {call,1,{f,14}}. % hit/1
    {'%',{var_info,{x,0},[{type,{t_integer,{0,1}}}]}}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{y,1},{t_integer,{0,'+inf'}}},{tr,{x,0},{t_integer,{0,1}}}],
            {x,3}}.
    {move,{y,2},{x,2}}.
    {move,{y,3},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,4,{f,26},4}. % spin/4


{function, wrap, 1, 29}.
  {label,28}.
    {line,[{location,"/home/user/beam-sharp/aoc/bench/bench_ex.ex",2}]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,wrap},1}.
  {label,29}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}],{x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{1,199}}},{integer,100}],
            {x,0}}.
    return.


{function, module_info, 0, 31}.
  {label,30}.
    {line,[]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,module_info},0}.
  {label,31}.
    {move,{atom,'Elixir.BenchEx'},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 33}.
  {label,32}.
    {line,[]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,module_info},1}.
  {label,33}.
    {move,{x,0},{x,1}}.
    {move,{atom,'Elixir.BenchEx'},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.


{function, '-inlined-__info__/1-', 1, 35}.
  {label,34}.
    {line,[]}.
    {func_info,{atom,'Elixir.BenchEx'},{atom,'-inlined-__info__/1-'},1}.
  {label,35}.
    {jump,{f,34}}.
