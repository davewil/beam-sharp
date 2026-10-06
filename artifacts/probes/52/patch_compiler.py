#!/usr/bin/env python3
"""Probe 52 helper: builds a PATCHED COPY of compiler/src in a scratch dir, never the repo.
usage: patch_compiler.py <variant> <outdir>      variant in: attr | inline | module | stock
Each variant adds an application name to the FFI declaration and does three things with it:
parse it, refuse at compile time if the app is not on the code path, emit it as a beam attribute.
The patch is applied by exact-string replacement; it aborts if a replaced string is not found,
so a drifted compiler/src cannot be silently half-patched."""
import sys, os, shutil, re, subprocess
variant, out = sys.argv[1], sys.argv[2]
root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
src = os.path.join(root, "compiler", "src")
if os.path.exists(out): shutil.rmtree(out)
os.makedirs(out + "/src"); os.makedirs(out + "/ebin")
for f in os.listdir(src):
    if f.endswith((".erl", ".xrl", ".yrl", ".hrl")): shutil.copy(os.path.join(src, f), out + "/src")
def sub(fn, old, new, count=1):
    if variant == "stock": return      # `stock` = the same build procedure with NO patch (a fair timing baseline)
    p = out + "/src/" + fn; s = open(p).read()
    if old not in s: sys.exit("PATCH FAILED (not found) in %s: %r" % (fn, old[:60]))
    open(p, "w").write(s.replace(old, new) if count == 0 else s.replace(old, new, count))

# ---- parser: the foreign decl gains a 5th element, the app (or `none`) ------------------------
sub("bs_parser.yrl", """foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$4'}.""",
"""foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$4', none}.""")
if variant == "inline":      # using :'Elixir.Req' in :req { ... }   -- `in` is already a keyword (comprehensions): no new word
    sub("bs_parser.yrl", "foreign_sigs -> foreign_sig              :",
"""foreign_decl -> 'using' atom_lit 'in' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$6', value('$4')}.

foreign_sigs -> foreign_sig              :""")
if variant == "attr":        # [app: req] using :'Elixir.Req' { ... }
    sub("bs_parser.yrl", "foreign_sigs -> foreign_sig              :",
"""foreign_decl -> '[' lident ':' lident ']' 'using' atom_lit '{' foreign_sigs '}' :
    case value('$2') of
        app -> {foreign, line('$6'), value('$7'), '$9', value('$4')};
        _ -> return_error(line('$2'), "expected `app`")
    end.

foreign_sigs -> foreign_sig              :""")
if variant == "module":      # needs :req   (module-level, its own decl)
    sub("bs_parser.yrl", "decl -> foreign_decl : '$1'.",
"""decl -> foreign_decl : '$1'.
decl -> lident atom_lit :
    case value('$1') of
        needs -> {needs, line('$1'), value('$2')};
        _ -> return_error(line('$1'), "expected `needs`")
    end.""")
# ---- checker: every {foreign,_,_,_} match gains the 5th element ------------------------------
sub("bs_check.erl", "{foreign, _, Mod, Sigs} <- Decls", "{foreign, _, Mod, Sigs, _} <- Decls", 0)
sub("bs_check.erl", "collapse_decl({foreign, _, _Mod, Sigs}, Env)", "collapse_decl({foreign, _, _Mod, Sigs, _}, Env)")
sub("bs_check.erl", "    foreign_rets_decidable(Decls, Env),\n    %% Scan bodies",
    "    foreign_rets_decidable(Decls, Env),\n    apps_on_code_path(Decls),\n    %% Scan bodies")
sub("bs_check.erl", "foreign_rets_decidable(Decls, Env) ->",
"""%% PROTOTYPE (ticket 52): a NAME-ONLY check. Decided against the compile machine's code path.
apps_on_code_path(Decls) ->
    Apps = [{L, Mod, A} || {foreign, L, Mod, _, A} <- Decls, A =/= none]
        ++ [{L, none, A} || {needs, L, A} <- Decls],
    _ = [case code:lib_dir(A) of
             {error, _} -> erlang:error({app_not_on_code_path, L, Mod, A});
             _ -> ok
         end || {L, Mod, A} <- Apps],
    ok.

foreign_rets_decidable(Decls, Env) ->""")
sub("bs_check.erl", "behaviours => [B || {behaviour, _, B} <- Decls],",
    "behaviours => [B || {behaviour, _, B} <- Decls],\n"
    "                         needs => lists:usort([A || {foreign, _, _, _, A} <- Decls, A =/= none]\n"
    "                                              ++ [A || {needs, _, A} <- Decls]),")
# ---- emitter: -bs_needs([...]) after the behaviours -------------------------------------------
sub("bs_emit.erl", "    ++ [{attribute, ?A, behaviour, bs_otp:behaviour_name(B)} || B <- Behaviours]",
    "    ++ [{attribute, ?A, behaviour, bs_otp:behaviour_name(B)} || B <- Behaviours]\n"
    "    ++ case maps:get(needs, Module, []) of [] -> []; Ns -> [{attribute, ?A, bs_needs, Ns}] end")
# ---- diagnostic -------------------------------------------------------------------------------
sub("bs_diag.erl", "built(Path, {unknown_generic, N}) ->",
"""built(Path, {app_not_on_code_path, Line, Mod, App}) ->
    #{tag => app_not_on_code_path, severity => error, file => Path, line => Line,
      module => case Mod of none -> "the module"; _ -> bs_types:atom_str(Mod) end, app => App};
built(Path, {unknown_generic, N}) ->""")
sub("bs_diag.erl", "message(#{tag := unknown_generic, file := P, type := N}) ->",
"""message(#{tag := app_not_on_code_path, module := Mod, app := App} = D) ->
    {placed(D) ++ "error: application `~s` (needed by ~s) is not on the code path~n"
     "  add its lib directory to ERL_LIBS, or remove the declaration~n",
     placed_args(D) ++ [App, Mod]};
message(#{tag := unknown_generic, file := P, type := N}) ->""")
# ---- build ------------------------------------------------------------------------------------
r = subprocess.run(["erl","-noshell","-eval",
    'leex:file("bs_lexer.xrl",[{error_location,column}]), yecc:file("bs_parser.yrl",[verbose]), halt().'],
    cwd=out+"/src", capture_output=True, text=True)
log = r.stdout + r.stderr
print("yecc: shift/reduce conflicts reported: %d" % log.count("Parse action conflict"))
r = subprocess.run("erlc +debug_info -o ../ebin *.erl 2>&1 | grep -iv warning | grep -i error | head -20; cp bsc.app.src ../ebin/bsc.app 2>/dev/null; true", shell=True, cwd=out+"/src", capture_output=True, text=True)
print("erlc errors:", r.stdout.strip()[:1500] or "none")
