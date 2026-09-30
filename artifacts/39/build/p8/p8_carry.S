{module, p8_carry}.  %% version = 0

{exports, [{a,1},{b,1},{c,1},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 21}.


{function, wa, 1, 2}.
  {label,1}.
    {line,[{location,"build/p8/p8_carry.erl",8}]}.
    {func_info,{atom,p8_carry},{atom,wa},1}.
  {label,2}.
    {gc_bif,'rem',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}],{x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{1,199}}},{integer,100}],
            {x,0}}.
    return.


{function, wb, 1, 4}.
  {label,3}.
    {line,[{location,"build/p8/p8_carry.erl",10}]}.
    {func_info,{atom,p8_carry},{atom,wb},1}.
  {label,4}.
    {gc_bif,'rem',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}],{x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{1,199}}},{integer,100}],
            {x,0}}.
    return.


{function, wc, 1, 6}.
  {label,5}.
    {line,[{location,"build/p8/p8_carry.erl",11}]}.
    {func_info,{atom,p8_carry},{atom,wc},1}.
  {label,6}.
    {gc_bif,'rem',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,100}],{x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{1,199}}},{integer,100}],
            {x,0}}.
    {test,is_ge,{f,7},[{tr,{x,0},{t_integer,{0,99}}},{integer,0}]}.
    return.
  {label,7}.
    {case_end,{x,0}}.


{function, hit, 1, 9}.
  {label,8}.
    {line,[{location,"build/p8/p8_carry.erl",12}]}.
    {func_info,{atom,p8_carry},{atom,hit},1}.
  {label,9}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.
    {test,is_eq_exact,{f,10},[{tr,{x,0},{t_integer,any}},{integer,0}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,10}.
    {move,{integer,0},{x,0}}.
    return.


{function, a, 1, 12}.
  {label,11}.
    {line,[{location,"build/p8/p8_carry.erl",14}]}.
    {func_info,{atom,p8_carry},{atom,a},1}.
  {label,12}.
    {allocate,0,1}.
    {call,1,{f,2}}. % wa/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,1}],{x,0}}.
    {call_last,1,{f,9},0}. % hit/1


{function, b, 1, 14}.
  {label,13}.
    {line,[{location,"build/p8/p8_carry.erl",15}]}.
    {func_info,{atom,p8_carry},{atom,b},1}.
  {label,14}.
    {allocate,0,1}.
    {call,1,{f,4}}. % wb/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,1}],{x,0}}.
    {call_last,1,{f,9},0}. % hit/1


{function, c, 1, 16}.
  {label,15}.
    {line,[{location,"build/p8/p8_carry.erl",16}]}.
    {func_info,{atom,p8_carry},{atom,c},1}.
  {label,16}.
    {allocate,0,1}.
    {call,1,{f,6}}. % wc/1
    {'%',{var_info,{x,0},[{type,{t_integer,{-99,99}}}]}}.
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,{-99,99}}},{integer,1}],{x,0}}.
    {call_last,1,{f,9},0}. % hit/1


{function, module_info, 0, 18}.
  {label,17}.
    {line,[]}.
    {func_info,{atom,p8_carry},{atom,module_info},0}.
  {label,18}.
    {move,{atom,p8_carry},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 20}.
  {label,19}.
    {line,[]}.
    {func_info,{atom,p8_carry},{atom,module_info},1}.
  {label,20}.
    {move,{x,0},{x,1}}.
    {move,{atom,p8_carry},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
