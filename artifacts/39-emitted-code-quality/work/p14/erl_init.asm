    align 8
L23:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# erl_init:start/2
    call L24
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xA7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start/2:
# i_breakpoint_trampoline
    short jmp L25
.db 0x90
    call L26
L25:
# i_test_yield
    lea rdx, qword ptr [start/2+24]
    dec r14d
    long jle L27
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L28
    mov ecx, 2
    call 139636653423200
L28:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# line_I
# i_call_ext_e
L29:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# line_I
# i_call_ext_e
L30:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# line_I
# i_call_ext_e
L31:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# line_I
# i_call_ext_e
L32:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L33
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L33:
# i_move_sd
L34:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 78859
# line_I
# i_call_f
.db 0x66, 0x90
    call label_11
# i_move_sd
    mov qword ptr [rbx+8], 81291
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 16
    jmp label_6
# i_func_label_L
    align 8
label_3:
# func_line_I
# i_func_info_IaaI
# erl_init:restart/0
    call L24
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x93, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
restart/0:
# i_breakpoint_trampoline
    short jmp L35
.db 0x90
    call L26
L35:
# i_test_yield
    lea rdx, qword ptr [restart/0+24]
    dec r14d
    long jle L27
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L36
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L36:
# line_I
# call_light_bif_be
    align 4
L37:
L38:
    long mov rcx, 9223372036854775807
    mov rax, 94068435904400
    lea rdx, qword ptr [L37]
# BIF: erts_internal:erase_persistent_terms/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L39
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L39:
# i_move_sd
L40:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 78859
# i_call_last_ft
    jmp label_11
# i_func_label_L
    align 8
label_5:
# func_line_I
# i_func_info_IaaI
# erl_init:run/3
    call L24
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_6:
# i_breakpoint_trampoline
    short jmp L41
.db 0x90
    call L26
L41:
# i_test_yield
    lea rdx, qword ptr [label_6+24]
    dec r14d
    long jle L27
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L42
    mov ecx, 3
    call 139636653423200
L42:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+8], r11
# i_move_sd
    mov qword ptr [rbx+16], 31
# line_I
# call_light_bif_be
    align 4
L43:
L44:
    long mov rcx, 9223372036854775807
    mov rax, 94068436111984
    lea rdx, qword ptr [L43]
# BIF: erlang:function_exported/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_8
    cmp rsi, 75
    je label_7
    jmp label_9
# label_L
label_7:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+16], 81291
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# line_I
# apply_last_tt
    add rsp, 16
    align 4
L46:
    mov edx, 1
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    lea rcx, qword ptr [L46]
    xor r8d, r8d
    call 94068435489472
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    short jne L45
    lea rsi, qword ptr [L46]
    mov rcx, 94068445024480
    push rsi
    jmp L47
L45:
    jmp qword ptr [rax+r12*8]
# label_L
label_8:
# test_heap_It
    lea rdx, qword ptr [r15+96]
    cmp rdx, rsp
    short jbe L48
    xor ecx, ecx
    call 139636653423200
L48:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 448
# Move tuple data
    mov qword ptr [r15+8], 81355
    mov qword ptr [r15+16], 779
    mov qword ptr [r15+24], 27723
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+32], rdi
L49:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+40], rdi
    mov qword ptr [r15+48], 81291
L50:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+56], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 64
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 16
# line_I
# call_light_bif_be
    align 4
L51:
L52:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109200
    lea rdx, qword ptr [L51]
# BIF: erlang:display/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx], 31
# i_call_ext_last_et
L53:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_9:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L54
# i_func_label_L
    nop
    align 8
label_10:
# func_line_I
# i_func_info_IaaI
# erl_init:if_loaded/2
    call L24
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x3E, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_11:
# i_breakpoint_trampoline
    short jmp L55
.db 0x90
    call L26
L55:
# i_test_yield
    lea rdx, qword ptr [label_11+24]
    dec r14d
    long jle L27
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L56
    mov ecx, 2
    call 139636653423200
L56:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# line_I
# call_light_bif_be
    align 4
L57:
L58:
    long mov rcx, 9223372036854775807
    mov rax, 94068435507248
    lea rdx, qword ptr [L57]
# BIF: erlang:loaded/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rbx+16], r11
# i_move_sd
    mov qword ptr [rbx], 78859
# i_call_last_ft
    add rsp, 8
    jmp label_13
# i_func_label_L
    align 8
label_12:
# func_line_I
# i_func_info_IaaI
# erl_init:if_loaded/3
    call L24
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x3E, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_13:
# i_breakpoint_trampoline
    short jmp L59
.db 0x90
    call L26
L59:
# i_test_yield
    lea rdx, qword ptr [label_13+24]
    dec r14d
    long jle L27
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx+16]
    test al, 2
    jne label_15
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rax-1], 1
    vmovups xmmword ptr [rbx+16], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 78859
    jne label_14
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L60
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L60:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_fun2_last_atSt
# simplified fetching of BEAM register
    mov rcx, r10
    mov edx, 20
    lea r8, qword ptr [L61]
# skipped box test since source is always boxed
# skipped fun/arity test since source is always a fun of the right arity when boxed
    mov rax, qword ptr [rcx+6]
    mov rdi, qword ptr [rax+r12*8]
L61:
    jmp rdi
# label_L
label_14:
# i_call_only_f
    short jmp label_13
# label_L
label_15:
# is_nil_fS
    cmp byte ptr [rbx+16], 59
    jne label_12
# i_move_sd
    mov qword ptr [rbx], 32075
# return
    dec r14d
    jl L62
    ret
# i_func_label_L
    align 8
label_16:
# func_line_I
# i_func_info_IaaI
# erl_init:module_info/0
    call L24
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L63
.db 0x90
    call L26
L63:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L27
    align 4
# i_move_sd
    mov qword ptr [rbx], 15179
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L64
    mov ecx, 1
.db 0x90
    call 139636653423200
L64:
# call_light_bif_be
    align 4
L65:
L66:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L65]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L62
    ret
# i_func_label_L
    align 8
label_18:
# func_line_I
# i_func_info_IaaI
# erl_init:module_info/1
    call L24
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L67
.db 0x90
    call L26
L67:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L27
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 15179
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L68
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L68:
# call_light_bif_be
    align 4
L69:
L70:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L69]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L62
    ret
# i_func_label_L
    align 8
label_20:
# func_line_I
# i_func_info_IaaI
# erl_init:'-restart/0-fun-0-'/0
    call L24
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x3E, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_21:
# i_breakpoint_trampoline
    short jmp L71
.db 0x90
    call L26
L71:
# i_test_yield
    lea rdx, qword ptr [label_21+24]
    dec r14d
    long jle L27
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L72
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L72:
# line_I
# i_call_ext_e
L73:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L62
    ret
# i_func_label_L
    align 8
label_22:
# func_line_I
# i_func_info_IaaI
# erl_init:'-start/2-fun-0-'/0
    call L24
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x3E, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_23:
# i_breakpoint_trampoline
    short jmp L74
.db 0x90
    call L26
L74:
# i_test_yield
    lea rdx, qword ptr [label_23+24]
    dec r14d
    long jle L27
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L75
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L75:
# line_I
# i_call_ext_e
L76:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# line_I
# i_call_ext_e
L77:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L62
    ret
# int_code_end
L78:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L62:
    jmp 139636653422960
L54:
    jmp 139636653427776
L47:
    jmp 139636653427784
L27:
    jmp 139636653426040
L26:
    jmp 139636653424496
L24:
    jmp 139636653424856
.section .rodata {#1}
md5:
.db 0xA1, 0x3C, 0xAC, 0xAA, 0x1A, 0x8C, 0xD1, 0x31, 0x2F, 0x4A, 0x67, 0x59, 0xD8, 0xDF, 0xF8, 0x7B
.section .text {#0}
