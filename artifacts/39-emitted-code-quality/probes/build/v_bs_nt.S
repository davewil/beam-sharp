{module, v_bs_nt}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{part_two,1}]}.

{attributes, []}.

{labels, 25}.


{function, wrap, 1, 2}.
  {label,1}.
    {line,[{location,"build/src/v_bs_nt.erl",47}]}.
    {func_info,{atom,v_bs_nt},{atom,wrap},1}.
  {label,2}.
    {gc_bif,'rem',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    {gc_bif,'+',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    {gc_bif,'rem',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    return.


{function, hit, 1, 4}.
  {label,3}.
    {line,[{location,"build/src/v_bs_nt.erl",51}]}.
    {func_info,{atom,v_bs_nt},{atom,hit},1}.
  {label,4}.
    {test,is_eq_exact,{f,5},[{x,0},{integer,0}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,5}.
    {move,{integer,0},{x,0}}.
    return.


{function, spin, 4, 7}.
  {label,6}.
    {line,[{location,"build/src/v_bs_nt.erl",66}]}.
    {func_info,{atom,v_bs_nt},{atom,spin},4}.
  {label,7}.
    {test,is_eq_exact,{f,8},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,8}.
    {line,[{location,"build/src/v_bs_nt.erl",68}]}.
    {gc_bif,'+',{f,0},4,[{x,0},{x,1}],{x,0}}.
    {allocate,4,4}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,3},{y,1}}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {call,1,{f,2}}. % wrap/1
    {line,[{location,"build/src/v_bs_nt.erl",69}]}.
    {gc_bif,'-',{f,0},1,[{y,2},{integer,1}],{y,2}}.
    {move,{x,0},{y,0}}.
    {call,1,{f,4}}. % hit/1
    {gc_bif,'+',{f,0},1,[{y,1},{x,0}],{x,3}}.
    {move,{y,2},{x,2}}.
    {move,{y,3},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,4,{f,7},4}. % spin/4


{function, sign, 1, 10}.
  {label,9}.
    {line,[{location,"build/src/v_bs_nt.erl",74}]}.
    {func_info,{atom,v_bs_nt},{atom,sign},1}.
  {label,10}.
    {test,is_lt,{f,11},[{x,0},{integer,0}]}.
    {move,{integer,-1},{x,0}}.
    return.
  {label,11}.
    {move,{integer,1},{x,0}}.
    return.


{function, size_, 1, 13}.
  {label,12}.
    {line,[{location,"build/src/v_bs_nt.erl",76}]}.
    {func_info,{atom,v_bs_nt},{atom,size_},1}.
  {label,13}.
    {test,is_lt,{f,14},[{x,0},{integer,0}]}.
    {gc_bif,'-',{f,0},1,[{x,0}],{x,0}}.
    return.
  {label,14}.
    return.


{function, clicks, 3, 16}.
  {label,15}.
    {line,[{location,"build/src/v_bs_nt.erl",86}]}.
    {func_info,{atom,v_bs_nt},{atom,clicks},3}.
  {label,16}.
    {test,is_nonempty_list,{f,17},[{x,0}]}.
    {allocate,4,3}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {get_list,{x,0},{y,1},{y,0}}.
    {move,{y,1},{x,0}}.
    {line,[{location,"build/src/v_bs_nt.erl",88}]}.
    {call,1,{f,10}}. % sign/1
    {swap,{y,1},{x,0}}.
    {call,1,{f,13}}. % size_/1
    {move,{x,0},{x,2}}.
    {move,{y,1},{x,1}}.
    {move,{y,2},{x,3}}.
    {move,{y,3},{x,0}}.
    {move,{y,0},{y,3}}.
    {trim,3,1}.
    {call,4,{f,7}}. % spin/4
    {test,is_tuple,{f,18},[{x,0}]}.
    {test,test_arity,{f,18},[{x,0},2]}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,16},1}. % clicks/3
  {label,17}.
    {test,is_nil,{f,15},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.
  {label,18}.
    {badmatch,{x,0}}.


{function, part_two, 1, 20}.
  {label,19}.
    {line,[{location,"build/src/v_bs_nt.erl",91}]}.
    {func_info,{atom,v_bs_nt},{atom,part_two},1}.
  {label,20}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,16}}. % clicks/3


{function, module_info, 0, 22}.
  {label,21}.
    {line,[]}.
    {func_info,{atom,v_bs_nt},{atom,module_info},0}.
  {label,22}.
    {move,{atom,v_bs_nt},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 24}.
  {label,23}.
    {line,[]}.
    {func_info,{atom,v_bs_nt},{atom,module_info},1}.
  {label,24}.
    {move,{x,0},{x,1}}.
    {move,{atom,v_bs_nt},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
