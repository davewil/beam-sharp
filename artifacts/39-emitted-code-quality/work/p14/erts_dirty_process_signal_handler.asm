    align 8
L33:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# erts_dirty_process_signal_handler:start/0
    call L34
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x7C, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xA7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start/0:
# i_breakpoint_trampoline
    short jmp L35
.db 0x90
    call L36
L35:
# i_test_yield
    lea rdx, qword ptr [start/0+24]
    dec r14d
    long jle L37
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L38
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L38:
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx], 45387
# line_I
# call_light_bif_be
    align 4
L39:
L40:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L39]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_call_last_ft
    jmp label_4
# i_func_label_L
    align 8
label_3:
# func_line_I
# i_func_info_IaaI
# erts_dirty_process_signal_handler:msg_loop/0
    call L34
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x7C, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x79, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_4:
# i_breakpoint_trampoline
    short jmp L41
.db 0x90
    call L36
L41:
# i_test_yield
    lea rdx, qword ptr [label_4+24]
    dec r14d
    long jle L37
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L42
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L42:
    sub rsp, 8
# init_yregs_I
    mov qword ptr [rsp], 59
# aligned_label_Lt
    align 4
label_5:
# i_loop_rec_f
    align 4
L43:
    lea rdi, qword ptr [L43]
    lea rsi, qword ptr [label_8]
    call 139636653425768
# remove_message
    mov rdx, r15
    mov rcx, rsp
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov esi, r14d
    mov r8, r12
    call 94068434774912
    mov r14d, eax
    mov rsp, rbp
# catch_yf
    inc qword ptr [r13+256]
L44:
    mov eax, 2147483647
    mov qword ptr [rsp], rax
# line_I
# i_call_f
.db 0x66, 0x90
    call label_10
# try_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp], 59
# jump_f
    jmp label_7
# label_L
label_6:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# label_L
label_7:
# i_call_last_ft
    add rsp, 8
    jmp label_4
# aligned_label_Lt
    align 4
label_8:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_5]
    call 94068434775632
    mov rsp, rbp
    jmp L45
# i_func_label_L
    align 8
label_9:
# func_line_I
# i_func_info_IaaI
# erts_dirty_process_signal_handler:handle_request/1
    call L34
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x7C, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x36, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_10:
# i_breakpoint_trampoline
    short jmp L46
.db 0x90
    call L36
L46:
# i_test_yield
    lea rdx, qword ptr [label_10+24]
    dec r14d
    long jle L37
    align 4
# is_pid_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L47
    test al, 1
    jne label_11
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_11
L47:
# i_move_sd
    mov qword ptr [rbx+8], 15
# i_call_only_f
    jmp label_21
# label_L
label_11:
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_17
    cmp dword ptr [rsi-2], 256
    jne label_17
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx+8], r10
# i_is_tuple_of_arity_fsA
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_17
    cmp dword ptr [rsi-2], 192
    jne label_17
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L48
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L48:
    sub rsp, 32
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+16], xmm0
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+16], xmm0
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+32], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+6], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov qword ptr [rbx+40], 15
# i_move_sd
    mov rdx, qword ptr [rsp+8]
    mov qword ptr [rbx], rdx
# line_I
# i_call_f
.db 0x66, 0x90
    call label_25
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 523
    je label_12
    cmp rsi, 7627
    je label_16
    cmp rsi, 162891
    je label_15
    jmp label_19
# label_L
label_12:
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+24]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov rdx, qword ptr [rsp+16]
    mov qword ptr [rbx+24], rdx
# i_move_sd
    mov rcx, qword ptr [rsp+8]
    mov qword ptr [rbx], rcx
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# line_I
# call_light_bif_be
    align 4
L49:
L50:
    long mov rcx, 9223372036854775807
    mov rax, 94068434652096
    lea rdx, qword ptr [L49]
# BIF: erts_internal:request_system_task/4
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 12427
    je label_14
    cmp rsi, 32075
    je label_13
    jmp label_18
# label_L
label_13:
# deallocate_t
    add rsp, 32
# return
    dec r14d
    jl L51
    ret
# label_L
label_14:
# i_move_sd
    mov r10, qword ptr [rsp+24]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 32
    jmp label_10
# label_L
label_15:
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 32
# return
    dec r14d
    jl L51
    ret
# label_L
label_16:
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+24]
    mov qword ptr [rbx+8], r11
# line_I
# send
    align 4
L52:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L52]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 32
# return
    dec r14d
    jl L51
    ret
# label_L
label_17:
# i_move_sd
    mov qword ptr [rbx], 21515
# return
    dec r14d
    jl L51
    ret
# label_L
label_18:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L53
# label_L
label_19:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L53
# i_func_label_L
    nop
    align 8
label_20:
# func_line_I
# i_func_info_IaaI
# erts_dirty_process_signal_handler:handle_incoming_signals/2
    call L34
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x7C, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x7C, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_21:
# i_breakpoint_trampoline
    short jmp L54
.db 0x90
    call L36
L54:
# i_test_yield
    lea rdx, qword ptr [label_21+24]
    dec r14d
    long jle L37
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 95
    jne label_22
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L55
    mov ecx, 1
.db 0x90
    call 139636653423200
L55:
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# self_d
    mov r11, qword ptr [r13]
    mov qword ptr [rbx], r11
# line_I
# send
    align 4
L56:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L56]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L51
    ret
# label_L
label_22:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L57
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L57:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# line_I
# call_light_bif_be
    align 4
L58:
L59:
    long mov rcx, 9223372036854775807
    mov rax, 94068436335328
    lea rdx, qword ptr [L58]
# BIF: erts_internal:dirty_process_handle_signals/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 28235
    jne label_23
# line_I
# i_plus_ssjd
    mov rsi, qword ptr [rsp]
    mov edx, 31
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L61
    lea rax, qword ptr [rsi-15]
    add rax, rdx
    short jno L60
L61:
    call L62
L60:
    mov qword ptr [rbx+8], rax
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 16
    jmp label_21
# label_L
label_23:
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L51
    ret
# i_func_label_L
    align 8
label_24:
# func_line_I
# i_func_info_IaaI
# erts_dirty_process_signal_handler:handle_sys_task/6
    call L34
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x7C, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x7C, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_25:
# i_breakpoint_trampoline
    short jmp L63
.db 0x90
    call L36
L63:
# i_test_yield
    lea rdx, qword ptr [label_25+24]
    dec r14d
    long jle L37
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 53835
    short jne label_24
# allocate_tt
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L64
    mov ecx, 6
.db 0x66, 0x90
    call 139636653423200
L64:
    sub rsp, 40
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+32], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rsp+16], r10
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+24], xmm0
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rbx], r11
# i_move_sd
    mov rdx, qword ptr [rbx+32]
    mov qword ptr [rbx+8], rdx
# line_I
# call_light_bif_be
    align 4
L65:
L66:
    long mov rcx, 9223372036854775807
    mov rax, 94068435505616
    lea rdx, qword ptr [L65]
# BIF: erts_internal:check_dirty_process_code/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
# (Src == 0xb || Src == 0x4b) <=> (Src | 0x40) == 0x4b
    mov eax, 64
    or rax, rsi
    cmp rax, 75
    je label_26
    cmp rsi, 7627
    je label_27
    jmp label_29
# label_L
label_26:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L67
    mov ecx, 1
.db 0x90
    call 139636653423200
L67:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 53835
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+32]
    mov qword ptr [rbx], r11
# i_trim_t
    add rsp, 40
# line_I
# send
    align 4
L68:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L68]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx], 162891
# deallocate_t
# return
    dec r14d
    jl L51
    ret
# label_L
label_27:
# is_ge_fss
    mov esi, 111
    mov rdi, qword ptr [rsp]
# simplified test because it always succeeds when LHS is a bignum
    rex test dil, 1
    short je L72
L70:
    cmp rdi, rsi
L69:
L71:
    jl label_28
L72:
# i_move_sd
    mov qword ptr [rbx], 7627
# deallocate_t
    add rsp, 40
# return
    dec r14d
    jl L51
    ret
# label_L
label_28:
# line_I
# i_plus_ssjd
# add without overflow check
    mov rax, qword ptr [rsp]
    add rax, 16
    mov qword ptr [rbx+40], rax
# i_move_sd
    mov qword ptr [rbx+16], 53835
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+8], 1
    vmovups xmmword ptr [rbx+24], xmm0
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+24], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 40
    jmp label_25
# label_L
label_29:
# deallocate_t
    add rsp, 40
# return
    dec r14d
    jl L51
    ret
# i_func_label_L
    align 8
label_30:
# func_line_I
# i_func_info_IaaI
# erts_dirty_process_signal_handler:module_info/0
    call L34
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x7C, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L73
.db 0x90
    call L36
L73:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L37
    align 4
# i_move_sd
    mov qword ptr [rbx], 162827
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L74
    mov ecx, 1
.db 0x90
    call 139636653423200
L74:
# call_light_bif_be
    align 4
L75:
L76:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L75]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L51
    ret
# i_func_label_L
    align 8
label_32:
# func_line_I
# i_func_info_IaaI
# erts_dirty_process_signal_handler:module_info/1
    call L34
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x7C, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L77
.db 0x90
    call L36
L77:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L37
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 162827
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L78
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L78:
# call_light_bif_be
    align 4
L79:
L80:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L79]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L51
    ret
# int_code_end
L81:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L53:
    jmp 139636653427776
L51:
    jmp 139636653422960
L45:
    jmp 139636653427727
L37:
    jmp 139636653426040
L62:
    jmp 139636653427096
L36:
    jmp 139636653424496
L34:
    jmp 139636653424856
.section .rodata {#1}
md5:
.db 0x54, 0x09, 0xC4, 0x55, 0x9F, 0xE7, 0x0E, 0x00, 0x09, 0x68, 0x6E, 0x60, 0xEA, 0x3D, 0x0B, 0x31
.section .text {#0}
