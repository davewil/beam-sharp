{module, v_abstr_rng}.  %% version = 0

{exports, [{bs@type_atoms,0},{module_info,0},{module_info,1},{part_two,1}]}.

{attributes, []}.

{labels, 35}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,{literal,#{}},{x,0}}.
    return.


{function, wrap, 1, 4}.
  {label,3}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,wrap},1}.
  {label,4}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {test,is_ge,{f,5},[{tr,{x,0},{t_integer,any}},{integer,-99}]}.
    {test,is_ge,{f,5},[{integer,199},{tr,{x,0},{t_integer,any}}]}.
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}],{x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{1,199}}},{integer,100}],
            {x,0}}.
    return.
  {label,5}.
    {call_only,1,{f,34}}. % '-inlined-wrap/1-'/1


{function, hit, 1, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,hit},1}.
  {label,7}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {test,is_eq_exact,{f,8},[{tr,{x,0},{t_integer,{-99,99}}},{integer,0}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,8}.
    {move,{integer,0},{x,0}}.
    return.


{function, spin, 4, 10}.
  {label,9}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,spin},4}.
  {label,10}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,any}}]}}.
    {test,is_eq_exact,{f,11},[{x,2},{integer,0}]}.
    {test,is_ge,{f,12},[{tr,{x,0},{t_integer,{-99,99}}},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,11}.
    {test,is_ge,{f,12},[{tr,{x,0},{t_integer,{-99,99}}},{integer,0}]}.
    {allocate,4,4}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,3},{y,1}}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-99,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {call,1,{f,4}}. % wrap/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {gc_bif,'-',{f,0},1,[{y,2},{integer,1}],{y,2}}.
    {move,{x,0},{y,0}}.
    {call,1,{f,7}}. % hit/1
    {'%',{var_info,{x,0},[{type,{t_integer,{0,1}}}]}}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{y,1},{t_integer,any}},{tr,{x,0},{t_integer,{0,1}}}],
            {x,3}}.
    {move,{y,2},{x,2}}.
    {move,{y,3},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,4,{f,10},4}. % spin/4
  {label,12}.
    {call_only,4,{f,32}}. % '-inlined-spin/4-'/4


{function, sign, 1, 14}.
  {label,13}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,sign},1}.
  {label,14}.
    {test,is_lt,{f,15},[{x,0},{integer,0}]}.
    {move,{integer,-1},{x,0}}.
    return.
  {label,15}.
    {move,{integer,1},{x,0}}.
    return.


{function, size_, 1, 17}.
  {label,16}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,size_},1}.
  {label,17}.
    {test,is_lt,{f,18},[{x,0},{integer,0}]}.
    {gc_bif,'-',{f,0},1,[{x,0}],{x,0}}.
    return.
  {label,18}.
    return.


{function, clicks, 3, 20}.
  {label,19}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,clicks},3}.
  {label,20}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,any}}]}}.
    {test,is_nonempty_list,{f,21},[{x,0}]}.
    {allocate,4,3}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {get_list,{x,0},{y,1},{y,0}}.
    {move,{y,1},{x,0}}.
    {call,1,{f,14}}. % sign/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-1,1}}}]}}.
    {swap,{y,1},{x,0}}.
    {call,1,{f,17}}. % size_/1
    {move,{x,0},{x,2}}.
    {move,{y,1},{x,1}}.
    {move,{y,2},{x,3}}.
    {move,{y,3},{x,0}}.
    {move,{y,0},{y,3}}.
    {trim,3,1}.
    {call,4,{f,10}}. % spin/4
    {'%',{var_info,{x,0},
                   [{type,{t_tuple,2,true,
                                   #{1 => {t_integer,{-99,99}},
                                     2 => {t_integer,any}}}}]}}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,20},1}. % clicks/3
  {label,21}.
    {test,is_nil,{f,22},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.
  {label,22}.
    {call_only,3,{f,30}}. % '-inlined-clicks/3-'/3


{function, part_two, 1, 24}.
  {label,23}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,part_two},1}.
  {label,24}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,20}}. % clicks/3


{function, module_info, 0, 26}.
  {label,25}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,module_info},0}.
  {label,26}.
    {move,{atom,v_abstr_rng},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 28}.
  {label,27}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,module_info},1}.
  {label,28}.
    {move,{x,0},{x,1}}.
    {move,{atom,v_abstr_rng},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.


{function, '-inlined-clicks/3-', 3, 30}.
  {label,29}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,'-inlined-clicks/3-'},3}.
  {label,30}.
    {jump,{f,29}}.


{function, '-inlined-spin/4-', 4, 32}.
  {label,31}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,'-inlined-spin/4-'},4}.
  {label,32}.
    {jump,{f,31}}.


{function, '-inlined-wrap/1-', 1, 34}.
  {label,33}.
    {line,[]}.
    {func_info,{atom,v_abstr_rng},{atom,'-inlined-wrap/1-'},1}.
  {label,34}.
    {jump,{f,33}}.
