{module, b_kind_b}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{part_two,1},{part_two,2}]}.

{attributes, []}.

{labels, 26}.


{function, wrap, 1, 2}.
  {label,1}.
    {line,[{location,"b_kind_b.erl",3}]}.
    {func_info,{atom,b_kind_b},{atom,wrap},1}.
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
    {line,[{location,"b_kind_b.erl",4}]}.
    {func_info,{atom,b_kind_b},{atom,hit},1}.
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
    {line,[{location,"b_kind_b.erl",6}]}.
    {func_info,{atom,b_kind_b},{atom,spin},4}.
  {label,7}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,any}}]}}.
    {test,is_eq_exact,{f,8},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,8}.
    {line,[{location,"b_kind_b.erl",8}]}.
    {gc_bif,'+',
            {f,0},
            4,
            [{tr,{x,0},{t_integer,any}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {allocate,4,4}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,3},{y,1}}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {call,1,{f,2}}. % wrap/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {line,[{location,"b_kind_b.erl",9}]}.
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
    {line,[{location,"b_kind_b.erl",10}]}.
    {func_info,{atom,b_kind_b},{atom,sign},1}.
  {label,10}.
    {test,is_lt,{f,11},[{x,0},{integer,0}]}.
    {move,{integer,-1},{x,0}}.
    return.
  {label,11}.
    {move,{integer,1},{x,0}}.
    return.


{function, size_, 1, 13}.
  {label,12}.
    {line,[{location,"b_kind_b.erl",12}]}.
    {func_info,{atom,b_kind_b},{atom,size_},1}.
  {label,13}.
    {test,is_lt,{f,14},[{x,0},{integer,0}]}.
    {gc_bif,'-',{f,0},1,[{x,0}],{x,0}}.
    return.
  {label,14}.
    return.


{function, clicks, 3, 16}.
  {label,15}.
    {line,[{location,"b_kind_b.erl",14}]}.
    {func_info,{atom,b_kind_b},{atom,clicks},3}.
  {label,16}.
    {'%',{var_info,{x,1},[{type,{t_integer,any}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,any}}]}}.
    {test,is_nonempty_list,{f,17},[{x,0}]}.
    {allocate,4,3}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {get_list,{x,0},{y,1},{y,0}}.
    {move,{y,1},{x,0}}.
    {line,[{location,"b_kind_b.erl",16}]}.
    {call,1,{f,10}}. % sign/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-1,1}}}]}}.
    {swap,{y,1},{x,0}}.
    {call,1,{f,13}}. % size_/1
    {move,{x,0},{x,2}}.
    {move,{y,1},{x,1}}.
    {move,{y,2},{x,3}}.
    {move,{y,3},{x,0}}.
    {move,{y,0},{y,3}}.
    {trim,3,1}.
    {call,4,{f,7}}. % spin/4
    {'%',{var_info,{x,0},
                   [{type,{t_tuple,2,true,
                                   #{1 => {t_integer,any},
                                     2 => {t_integer,any}}}}]}}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,16},1}. % clicks/3
  {label,17}.
    {test,is_nil,{f,15},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.


{function, part_two, 2, 19}.
  {label,18}.
    {line,[{location,"b_kind_b.erl",18}]}.
    {func_info,{atom,b_kind_b},{atom,part_two},2}.
  {label,19}.
    {test,is_integer,{f,18},[{x,1}]}.
    {move,{integer,0},{x,2}}.
    {call_only,3,{f,16}}. % clicks/3


{function, part_two, 1, 21}.
  {label,20}.
    {line,[{location,"b_kind_b.erl",19}]}.
    {func_info,{atom,b_kind_b},{atom,part_two},1}.
  {label,21}.
    {move,{integer,50},{x,1}}.
    {call_only,2,{f,19}}. % part_two/2


{function, module_info, 0, 23}.
  {label,22}.
    {line,[]}.
    {func_info,{atom,b_kind_b},{atom,module_info},0}.
  {label,23}.
    {move,{atom,b_kind_b},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 25}.
  {label,24}.
    {line,[]}.
    {func_info,{atom,b_kind_b},{atom,module_info},1}.
  {label,25}.
    {move,{x,0},{x,1}}.
    {move,{atom,b_kind_b},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
