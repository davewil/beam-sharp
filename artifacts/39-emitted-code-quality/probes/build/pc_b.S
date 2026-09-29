{module, pc_b}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{part_two,1}]}.

{attributes, []}.

{labels, 10}.


{function, part_two, 1, 2}.
  {label,1}.
    {line,[{location,"build/src/pc_b.erl",9}]}.
    {func_info,{atom,pc_b},{atom,part_two},1}.
  {label,2}.
    {move,{integer,0},{x,1}}.
    {move,{integer,5000000},{x,0}}.
    {call_only,2,{f,4}}. % l/2


{function, l, 2, 4}.
  {label,3}.
    {line,[{location,"build/src/pc_b.erl",10}]}.
    {func_info,{atom,pc_b},{atom,l},2}.
  {label,4}.
    {test,is_eq_exact,{f,5},[{x,0},{integer,0}]}.
    {move,{x,1},{x,0}}.
    return.
  {label,5}.
    {line,[{location,"build/src/pc_b.erl",12}]}.
    {gc_bif,'band',{f,0},2,[{x,0},{integer,255}],{x,2}}.
    {gc_bif,'band',{f,0},3,[{x,0},{integer,15}],{x,3}}.
    {line,[{location,"build/src/pc_b.erl",13}]}.
    {gc_bif,'+',{f,0},4,[{x,2},{x,3}],{x,4}}.
    {gc_bif,'+',{f,0},5,[{x,4},{x,2}],{x,4}}.
    {gc_bif,'+',{f,0},5,[{x,4},{x,3}],{x,4}}.
    {gc_bif,'+',{f,0},5,[{x,4},{x,2}],{x,4}}.
    {gc_bif,'+',{f,0},5,[{x,4},{x,3}],{x,4}}.
    {gc_bif,'+',{f,0},5,[{x,4},{x,2}],{x,4}}.
    {gc_bif,'+',{f,0},5,[{x,4},{x,3}],{x,4}}.
    {gc_bif,'+',{f,0},5,[{x,4},{x,2}],{x,2}}.
    {gc_bif,'+',{f,0},4,[{x,2},{x,3}],{x,2}}.
    {line,[{location,"build/src/pc_b.erl",14}]}.
    {gc_bif,'-',{f,0},3,[{x,0},{integer,1}],{x,0}}.
    {gc_bif,'+',{f,0},3,[{x,1},{x,2}],{x,1}}.
    {gc_bif,'band',{f,0},2,[{x,1},{integer,16777215}],{x,1}}.
    {call_only,2,{f,4}}. % l/2


{function, module_info, 0, 7}.
  {label,6}.
    {line,[]}.
    {func_info,{atom,pc_b},{atom,module_info},0}.
  {label,7}.
    {move,{atom,pc_b},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 9}.
  {label,8}.
    {line,[]}.
    {func_info,{atom,pc_b},{atom,module_info},1}.
  {label,9}.
    {move,{x,0},{x,1}}.
    {move,{atom,pc_b},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
