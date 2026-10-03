{module, b2_bs_no_type}.  %% version = 0

{exports, [{'PartTwo',1},{bs@type_atoms,0},{module_info,0},{module_info,1}]}.

{attributes, []}.

{labels, 28}.


{function, bs@type_atoms, 0, 2}.
  {label,1}.
    {line,[]}.
    {func_info,{atom,b2_bs_no_type},{atom,bs@type_atoms},0}.
  {label,2}.
    {move,nil,{x,0}}.
    return.


{function, 'Wrap', 1, 4}.
  {label,3}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",12}]}.
    {func_info,{atom,b2_bs_no_type},{atom,'Wrap'},1}.
  {label,4}.
    {gc_bif,'rem',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    {test,is_integer,{f,5},[{x,0}]}.
    {gc_bif,'+',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    {gc_bif,'rem',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    {test,is_integer,{f,5},[{x,0}]}.
    return.
  {label,5}.
    {case_end,{x,0}}.


{function, 'Hit', 1, 7}.
  {label,6}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",15}]}.
    {func_info,{atom,b2_bs_no_type},{atom,'Hit'},1}.
  {label,7}.
    {test,is_eq_exact,{f,8},[{x,0},{integer,0}]}.
    {move,{integer,1},{x,0}}.
    return.
  {label,8}.
    {move,{integer,0},{x,0}}.
    return.


{function, 'Spin', 4, 10}.
  {label,9}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",19}]}.
    {func_info,{atom,b2_bs_no_type},{atom,'Spin'},4}.
  {label,10}.
    {test,is_eq_exact,{f,11},[{x,2},{integer,0}]}.
    {test_heap,3,4}.
    {put_tuple2,{x,0},{list,[{x,0},{x,3}]}}.
    return.
  {label,11}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",21}]}.
    {gc_bif,'+',{f,0},4,[{x,0},{x,1}],{x,0}}.
    {allocate,4,4}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,3},{y,1}}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {call,1,{f,4}}. % 'Wrap'/1
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",22}]}.
    {gc_bif,'-',{f,0},1,[{y,2},{integer,1}],{y,2}}.
    {move,{x,0},{y,0}}.
    {call,1,{f,7}}. % 'Hit'/1
    {gc_bif,'+',{f,0},1,[{y,1},{x,0}],{x,3}}.
    {move,{y,2},{x,2}}.
    {move,{y,3},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,4,{f,10},4}. % 'Spin'/4


{function, 'Sign', 1, 13}.
  {label,12}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",25}]}.
    {func_info,{atom,b2_bs_no_type},{atom,'Sign'},1}.
  {label,13}.
    {test,is_lt,{f,14},[{x,0},{integer,0}]}.
    {move,{integer,-1},{x,0}}.
    return.
  {label,14}.
    {move,{integer,1},{x,0}}.
    return.


{function, 'Size', 1, 16}.
  {label,15}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",29}]}.
    {func_info,{atom,b2_bs_no_type},{atom,'Size'},1}.
  {label,16}.
    {test,is_lt,{f,17},[{x,0},{integer,0}]}.
    {gc_bif,'-',{f,0},1,[{x,0}],{x,0}}.
    return.
  {label,17}.
    return.


{function, 'Clicks', 3, 19}.
  {label,18}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",33}]}.
    {func_info,{atom,b2_bs_no_type},{atom,'Clicks'},3}.
  {label,19}.
    {test,is_nonempty_list,{f,20},[{x,0}]}.
    {allocate,4,3}.
    {move,{x,2},{y,2}}.
    {move,{x,1},{y,3}}.
    {get_list,{x,0},{y,1},{y,0}}.
    {move,{y,1},{x,0}}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",35}]}.
    {call,1,{f,13}}. % 'Sign'/1
    {swap,{y,1},{x,0}}.
    {call,1,{f,16}}. % 'Size'/1
    {move,{x,0},{x,2}}.
    {move,{y,1},{x,1}}.
    {move,{y,2},{x,3}}.
    {move,{y,3},{x,0}}.
    {move,{y,0},{y,3}}.
    {trim,3,1}.
    {call,4,{f,10}}. % 'Spin'/4
    {test,is_tuple,{f,21},[{x,0}]}.
    {test,test_arity,{f,21},[{x,0},2]}.
    {get_tuple_element,{x,0},0,{x,1}}.
    {get_tuple_element,{x,0},1,{x,2}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,19},1}. % 'Clicks'/3
  {label,20}.
    {test,is_nil,{f,18},[{x,0}]}.
    {move,{x,2},{x,0}}.
    return.
  {label,21}.
    {badmatch,{x,0}}.


{function, 'PartTwo', 1, 23}.
  {label,22}.
    {line,[{location,"aoc/bench/Day01/bench_bs.bs",39}]}.
    {func_info,{atom,b2_bs_no_type},{atom,'PartTwo'},1}.
  {label,23}.
    {move,{integer,0},{x,2}}.
    {move,{integer,50},{x,1}}.
    {call_only,3,{f,19}}. % 'Clicks'/3


{function, module_info, 0, 25}.
  {label,24}.
    {line,[]}.
    {func_info,{atom,b2_bs_no_type},{atom,module_info},0}.
  {label,25}.
    {move,{atom,b2_bs_no_type},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 27}.
  {label,26}.
    {line,[]}.
    {func_info,{atom,b2_bs_no_type},{atom,module_info},1}.
  {label,27}.
    {move,{x,0},{x,1}}.
    {move,{atom,b2_bs_no_type},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
