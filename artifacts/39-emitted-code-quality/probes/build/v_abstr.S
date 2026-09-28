{module, v_abstr}.  %% version = 0

{exports, [{bs@type_atoms,0},{module_info,0},{module_info,1},{part_two,1}]}.

{attributes, []}.

{labels, 29}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,{literal,#{}},{x,0}}.
    return.


{function, wrap, 1, 4}.
  {label,3}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,wrap},1}.
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


{function, hit, 1, 6}.
  {label,5}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,hit},1}.
  {label,6}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {test,is_eq_exact,{f,7},[{tr,{x,0},{t_integer,{-99,99}}},{integer,0}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,7}.
    {move,{integer,0},{x,0}}.
    return.


{function, spin, 4, 9}.
  {label,8}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,spin},4}.
  {label,9}.
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-1,1}}}]}}.
    {'%',{var_info,{x,3},[{type,{t_integer,any}}]}}.
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
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-99,99}}},{tr,{x,1},{t_integer,{-1,1}}}],
            {x,0}}.
    {call,1,{f,4}}. % wrap/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {gc_bif,'-',{f,0},1,[{y,2},{integer,1}],{y,2}}.
    {move,{x,0},{y,0}}.
    {call,1,{f,6}}. % hit/1
    {'%',{var_info,{x,0},[{type,{t_integer,{0,1}}}]}}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{y,1},{t_integer,any}},{tr,{x,0},{t_integer,{0,1}}}],
            {x,3}}.
    {move,{y,2},{x,2}}.
    {move,{y,3},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,4,{f,9},4}. % spin/4


{function, sign, 1, 12}.
  {label,11}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,sign},1}.
  {label,12}.
    {test,is_lt,{f,13},[{x,0},{integer,0}]}.
    {move,{integer,-1},{x,0}}.
    return.
  {label,13}.
    {move,{integer,1},{x,0}}.
    return.


{function, size_, 1, 15}.
  {label,14}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,size_},1}.
  {label,15}.
    {test,is_lt,{f,16},[{x,0},{integer,0}]}.
    {gc_bif,'-',{f,0},1,[{x,0}],{x,0}}.
    return.
  {label,16}.
    return.


{function, clicks, 3, 18}.
  {label,17}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,clicks},3}.
  {label,18}.
    {'%',{var_info,{x,1},[{type,{t_integer,{-99,99}}}]}}.
    {'%',{var_info,{x,2},[{type,{t_integer,any}}]}}.
    {test,is_nonempty_list,{f,19},[{x,0}]}.
    {allocate,4,3}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {get_list,{x,0},{y,1},{y,0}}.
    {move,{y,1},{x,0}}.
    {call,1,{f,12}}. % sign/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-1,1}}}]}}.
    {swap,{y,1},{x,0}}.
    {call,1,{f,15}}. % size_/1
    {move,{x,0},{x,2}}.
    {move,{y,1},{x,1}}.
    {move,{y,2},{x,3}}.
    {move,{y,3},{x,0}}.
    {move,{y,0},{y,3}}.
    {trim,3,1}.
    {call,4,{f,9}}. % spin/4
    {'%',{var_info,{x,0},
                   [{type,{t_tuple,2,true,
                                   #{1 => {t_integer,{-99,99}},
                                     2 => {t_integer,any}}}}]}}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,18},1}. % clicks/3
  {label,19}.
    {test,is_nil,{f,20},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.
  {label,20}.
    {call_only,3,{f,28}}. % '-inlined-clicks/3-'/3


{function, part_two, 1, 22}.
  {label,21}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,part_two},1}.
  {label,22}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,18}}. % clicks/3


{function, module_info, 0, 24}.
  {label,23}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,module_info},0}.
  {label,24}.
    {move,{atom,v_abstr},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 26}.
  {label,25}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,module_info},1}.
  {label,26}.
    {move,{x,0},{x,1}}.
    {move,{atom,v_abstr},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.


{function, '-inlined-clicks/3-', 3, 28}.
  {label,27}.
    {line,[]}.
    {func_info,{atom,v_abstr},{atom,'-inlined-clicks/3-'},3}.
  {label,28}.
    {jump,{f,27}}.
