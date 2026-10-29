{module, gtag}.  %% version = 0

{exports, [{loop_local,3},
           {loop_remote,3},
           {module_info,0},
           {module_info,1},
           {total,1}]}.

{attributes, []}.

{labels, 13}.


{function, total, 1, 2}.
  {label,1}.
    {line,[{location,"/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/59/p2/gtag.erl",
                     3}]}.
    {func_info,{atom,gtag},{atom,total},1}.
  {label,2}.
    {bif,map_get,{f,1},[{atom,'Kind'},{x,0}],{x,1}}.
    {test,is_eq_exact,{f,1},[{x,1},{atom,'M.Order'}]}.
    {bif,map_get,{f,0},[{atom,f1},{tr,{x,0},{t_map,any,any}}],{x,0}}.
    return.


{function, loop_local, 3, 4}.
  {label,3}.
    {line,[{location,"/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/59/p2/gtag.erl",
                     4}]}.
    {func_info,{atom,gtag},{atom,loop_local},3}.
  {label,4}.
    {test,is_eq_exact,{f,5},[{x,0},{integer,0}]}.
    {move,{x,2},{x,0}}.
    return.
  {label,5}.
    {line,[{location,"/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/59/p2/gtag.erl",
                     5}]}.
    {gc_bif,'-',{f,0},3,[{x,0},{integer,1}],{x,0}}.
    {allocate,3,3}.
    {move,{x,0},{y,0}}.
    {move,{x,2},{y,1}}.
    {move,{x,1},{y,2}}.
    {move,{x,1},{x,0}}.
    {call,1,{f,2}}. % total/1
    {gc_bif,'+',{f,0},1,[{y,1},{x,0}],{x,2}}.
    {move,{y,2},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,4},3}. % loop_local/3


{function, loop_remote, 3, 7}.
  {label,6}.
    {line,[{location,"/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/59/p2/gtag.erl",
                     6}]}.
    {func_info,{atom,gtag},{atom,loop_remote},3}.
  {label,7}.
    {test,is_eq_exact,{f,8},[{x,0},{integer,0}]}.
    {move,{x,2},{x,0}}.
    return.
  {label,8}.
    {line,[{location,"/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/59/p2/gtag.erl",
                     7}]}.
    {gc_bif,'-',{f,0},3,[{x,0},{integer,1}],{x,0}}.
    {allocate,3,3}.
    {move,{x,0},{y,0}}.
    {move,{x,2},{y,1}}.
    {move,{x,1},{y,2}}.
    {move,{x,1},{x,0}}.
    {call_ext,1,{extfunc,gtag,total,1}}.
    {gc_bif,'+',{f,0},1,[{y,1},{x,0}],{x,2}}.
    {move,{y,2},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,3,{f,7},3}. % loop_remote/3


{function, module_info, 0, 10}.
  {label,9}.
    {line,[]}.
    {func_info,{atom,gtag},{atom,module_info},0}.
  {label,10}.
    {move,{atom,gtag},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 12}.
  {label,11}.
    {line,[]}.
    {func_info,{atom,gtag},{atom,module_info},1}.
  {label,12}.
    {move,{x,0},{x,1}}.
    {move,{atom,gtag},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
