{module, g3}.  %% version = 0

{exports, [{bounded,1},{dv,2},{lit,1},{module_info,0},{module_info,1},{var,2}]}.

{attributes, []}.

{labels, 16}.


{function, lit, 1, 2}.
  {label,1}.
    {line,[{location,"src/g3.gleam",3}]}.
    {func_info,{atom,g3},{atom,lit},1}.
  {label,2}.
    {line,[{location,"src/g3.gleam",4}]}.
    {gc_bif,'rem',{f,0},1,[{x,0},{integer,100}],{x,0}}.
    return.


{function, var, 2, 4}.
  {label,3}.
    {line,[{location,"src/g3.gleam",4}]}.
    {func_info,{atom,g3},{atom,var},2}.
  {label,4}.
    {test,is_eq_exact,{f,5},[{x,1},{integer,0}]}.
    {move,{integer,0},{x,0}}.
    return.
  {label,5}.
    {line,[{location,"src/g3.gleam",7}]}.
    {gc_bif,'rem',{f,0},2,[{x,0},{x,1}],{x,0}}.
    return.


{function, dv, 2, 7}.
  {label,6}.
    {line,[{location,"src/g3.gleam",5}]}.
    {func_info,{atom,g3},{atom,dv},2}.
  {label,7}.
    {test,is_eq_exact,{f,8},[{x,1},{integer,0}]}.
    {move,{integer,0},{x,0}}.
    return.
  {label,8}.
    {line,[{location,"src/g3.gleam",8}]}.
    {gc_bif,'div',{f,0},2,[{x,0},{x,1}],{x,0}}.
    return.


{function, bounded, 1, 10}.
  {label,9}.
    {line,[{location,"src/g3.gleam",6}]}.
    {func_info,{atom,g3},{atom,bounded},1}.
  {label,10}.
    {test,is_ge,{f,11},[{x,0},{integer,0}]}.
    {test,is_ge,{f,11},[{integer,99},{x,0}]}.
    {line,[{location,"src/g3.gleam",9}]}.
    {gc_bif,'+',{f,0},1,[{x,0},{integer,1}],{x,0}}.
    return.
  {label,11}.
    {move,{integer,0},{x,0}}.
    return.


{function, module_info, 0, 13}.
  {label,12}.
    {line,[]}.
    {func_info,{atom,g3},{atom,module_info},0}.
  {label,13}.
    {move,{atom,g3},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 15}.
  {label,14}.
    {line,[]}.
    {func_info,{atom,g3},{atom,module_info},1}.
  {label,15}.
    {move,{x,0},{x,1}}.
    {move,{atom,g3},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
