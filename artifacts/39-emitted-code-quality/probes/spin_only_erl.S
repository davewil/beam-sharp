{module, spin_only_erl}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{spin,4}]}.

{attributes, []}.

{labels, 13}.


{function, wrap, 1, 2}.
  {label,1}.
    {line,[{location,"spin_only_erl.erl",7}]}.
    {func_info,{atom,spin_only_erl},{atom,wrap},1}.
  {label,2}.
    {'%',{var_info,{x,0},[{type,number}]}}.
    {gc_bif,'rem',{f,0},1,[{tr,{x,0},number},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}],{x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{1,199}}},{integer,100}],
            {x,0}}.
    return.


{function, hit, 1, 4}.
  {label,3}.
    {line,[{location,"spin_only_erl.erl",9}]}.
    {func_info,{atom,spin_only_erl},{atom,hit},1}.
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
    {line,[{location,"spin_only_erl.erl",12}]}.
    {func_info,{atom,spin_only_erl},{atom,spin},4}.
  {label,7}.
    {test,is_eq_exact,{f,8},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,8}.
    {line,[{location,"spin_only_erl.erl",14}]}.
    {gc_bif,'+',{f,0},4,[{x,0},{x,1}],{x,0}}.
    {allocate,4,4}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,3},{y,1}}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {call,1,{f,2}}. % wrap/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {line,[{location,"spin_only_erl.erl",15}]}.
    {gc_bif,'-',{f,0},1,[{y,2},{integer,1}],{y,2}}.
    {move,{x,0},{y,0}}.
    {call,1,{f,4}}. % hit/1
    {'%',{var_info,{x,0},[{type,{t_integer,{0,1}}}]}}.
    {gc_bif,'+',{f,0},1,[{y,1},{tr,{x,0},{t_integer,{0,1}}}],{x,3}}.
    {move,{y,2},{x,2}}.
    {move,{y,3},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,4,{f,7},4}. % spin/4


{function, module_info, 0, 10}.
  {label,9}.
    {line,[]}.
    {func_info,{atom,spin_only_erl},{atom,module_info},0}.
  {label,10}.
    {move,{atom,spin_only_erl},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 12}.
  {label,11}.
    {line,[]}.
    {func_info,{atom,spin_only_erl},{atom,module_info},1}.
  {label,12}.
    {move,{x,0},{x,1}}.
    {move,{atom,spin_only_erl},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
