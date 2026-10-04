    align 8
L34:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# erts_trace_cleaner:start/0
    call L35
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xA7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start/0:
# i_breakpoint_trampoline
    short jmp L36
.db 0x90
    call L37
L36:
# i_test_yield
    lea rdx, qword ptr [start/0+24]
    dec r14d
    long jle L38
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L39
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L39:
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx], 45387
# line_I
# call_light_bif_be
    align 4
L40:
L41:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L40]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx+16], 15
# i_move_sd
    mov qword ptr [rbx+8], 907
# i_move_sd
    mov qword ptr [rbx+24], 59
# i_move_sd
    mov qword ptr [rbx], 162571
# i_call_last_ft
    jmp label_4
# i_func_label_L
    align 8
label_3:
# func_line_I
# i_func_info_IaaI
# erts_trace_cleaner:loop/4
    call L35
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x4B, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_4:
# i_breakpoint_trampoline
    short jmp L42
.db 0x90
    call L37
L42:
# i_test_yield
    lea rdx, qword ptr [label_4+24]
    dec r14d
    long jle L38
    align 4
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 34379
    je label_6
    cmp rsi, 35275
    je label_5
    jmp label_7
# label_L
label_5:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 15
    jne label_11
# is_nil_fS
    cmp byte ptr [rbx+24], 59
    jne label_11
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L43
    mov ecx, 2
.db 0x90
    call 139636653423200
L43:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# call_light_bif_be
    align 4
L44:
L45:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109152
    lea rdx, qword ptr [L44]
# BIF: erlang:ports/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx+16], 15
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rbx+24], r11
# i_move_sd
    mov qword ptr [rbx], 34379
# i_call_last_ft
    add rsp, 8
    jmp label_4
# label_L
label_6:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 15
    jne label_11
# is_nil_fS
    cmp byte ptr [rbx+24], 59
    jne label_11
# i_call_only_f
    jmp label_18
# label_L
label_7:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 15
    jne label_11
# is_nil_fS
    cmp byte ptr [rbx+24], 59
    jne label_11
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L46
    xor ecx, ecx
.db 0x90
    call 139636653423200
L46:
# aligned_label_Lt
    align 4
label_8:
# i_loop_rec_f
    align 4
L47:
    lea rdi, qword ptr [L47]
    lea rsi, qword ptr [label_10]
    call 139636653425768
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 31691
    jne label_9
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
# i_call_last_ft
    jmp label_18
# label_L
label_9:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L48
    mov ecx, 1
.db 0x90
    call 139636653423200
L48:
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
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 71371
    mov qword ptr [r15+16], 162635
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L49:
L50:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109200
    lea rdx, qword ptr [L49]
# BIF: erlang:display/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx+16], 15
# i_move_sd
    mov qword ptr [rbx+8], 907
# i_move_sd
    mov qword ptr [rbx+24], 59
# i_move_sd
    mov qword ptr [rbx], 162571
# i_call_last_ft
    jmp label_4
# aligned_label_Lt
    align 4
label_10:
# wait_timeout_locked_sf
    mov esi, 960015
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rdx, qword ptr [L52]
    call 94068434776064
    mov rsp, rbp
    cmp rax, 1
    short je L51
    short jl L52
    lea rsi, qword ptr [label_10]
    xor ecx, ecx
    push rsi
    jmp L53
L51:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_8]
    call 94068434775632
    mov rsp, rbp
    jmp L54
    align 4
L52:
# timeout
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068434776496
    mov rsp, rbp
# i_move_sd
    mov qword ptr [rbx+8], 42827
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov qword ptr [rbx], 71371
# line_I
# i_call_ext_e
L55:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# deallocate_t
# return
    dec r14d
    jl L56
    ret
# label_L
label_11:
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx+24]
    test al, 2
    jne label_12
# (moving head and tail together)
    vmovups xmm0, xmmword ptr [rax-1]
    vmovups xmmword ptr [rbx+32], xmm0
# is_lt_fss
    mov rsi, qword ptr [rbx+8]
    mov rdi, qword ptr [rbx+16]
    cmp rdi, rsi
    short je L58
    mov eax, edi
    and eax, esi
    and al, 15
    cmp al, 15
    short jne L57
    cmp rdi, rsi
    short jmp L58
L57:
    call L60
L58:
    jge label_12
L59:
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L61
    mov ecx, 6
.db 0x90
    call 139636653423200
L61:
    sub rsp, 32
# i_move_sd
    mov r10, qword ptr [rbx+40]
    mov qword ptr [rsp], r10
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+24], r11
# i_move_sd
    mov rdx, qword ptr [rbx+32]
    mov qword ptr [rbx], rdx
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call label_23
# line_I
# i_plus_ssjd
    mov rsi, qword ptr [rsp+8]
    mov rdx, qword ptr [rbx]
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L63
    lea rax, qword ptr [rsi-15]
    add rax, rdx
    short jno L62
L63:
    call L64
L62:
    mov qword ptr [rbx+16], rax
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+24], r10
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+16], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 32
    jmp label_4
# label_L
label_12:
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L65
    mov ecx, 4
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L65:
    sub rsp, 32
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+16], 1
    vmovups xmmword ptr [rsp], xmm0
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+16], xmm0
# aligned_label_Lt
    align 4
label_13:
# i_loop_rec_f
    align 4
L66:
    lea rdi, qword ptr [L66]
    lea rsi, qword ptr [label_16]
    call 139636653425768
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 31691
    jne label_14
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
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+16], xmm0
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+16], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 32
    jmp label_4
# label_L
label_14:
# is_pid_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L67
    test al, 1
    jne label_15
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_15
L67:
# is_ge_fss
    mov esi, 31
    mov rdi, qword ptr [rsp+8]
# simplified small test for known integer
    rex test dil, 1
    short jne L69
    mov eax, dword ptr [rdi-2]
    test al, 4
    jne label_15
    short jmp L71
L69:
    cmp rdi, rsi
L68:
L70:
    jl label_15
L71:
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
# line_I
# i_minus_ssjd
    mov rsi, qword ptr [rsp+8]
    mov edx, 31
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L73
# skipped overflow test because the result is always small
    mov rax, rsi
    sub rax, 16
    short jmp L72
L73:
    call L74
L72:
    mov qword ptr [rbx+16], rax
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+24], r10
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+16], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 32
    jmp label_4
# label_L
label_15:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L75
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L75:
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
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 71371
    mov qword ptr [r15+16], 162635
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L76:
L77:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109200
    lea rdx, qword ptr [L76]
# BIF: erlang:display/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+16], xmm0
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+16], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 32
    jmp label_4
# aligned_label_Lt
    align 4
label_16:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_13]
    call 94068434775632
    mov rsp, rbp
    jmp L54
# i_func_label_L
    align 8
label_17:
# func_line_I
# i_func_info_IaaI
# erts_trace_cleaner:call_check/0
    call L35
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x7B, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_18:
# i_breakpoint_trampoline
    short jmp L78
.db 0x90
    call L37
L78:
# i_test_yield
    lea rdx, qword ptr [label_18+24]
    dec r14d
    long jle L38
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L79
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L79:
    sub rsp, 8
# init_yregs_I
    mov qword ptr [rsp], 59
# line_I
# call_light_bif_be
    align 4
L80:
L81:
    long mov rcx, 9223372036854775807
    mov rax, 94068435929552
    lea rdx, qword ptr [L80]
# BIF: erts_trace_cleaner:check/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_20
    cmp rsi, 75
    je label_19
    jmp label_21
# label_L
label_19:
# call_light_bif_be
    align 4
L82:
L83:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109040
    lea rdx, qword ptr [L82]
# BIF: erlang:processes/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov qword ptr [rbx], 33227
# line_I
# call_light_bif_be
    align 4
L84:
L85:
    long mov rcx, 9223372036854775807
    mov rax, 94068435859296
    lea rdx, qword ptr [L84]
# BIF: erlang:system_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx+16], 15
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx+24], r11
# i_move_sd
    mov qword ptr [rbx], 35275
# i_call_last_ft
    add rsp, 8
    jmp label_4
# label_L
label_20:
# i_move_sd
    mov qword ptr [rbx+16], 15
# i_move_sd
    mov qword ptr [rbx+8], 907
# i_move_sd
    mov qword ptr [rbx+24], 59
# i_move_sd
    mov qword ptr [rbx], 162571
# i_call_last_ft
    add rsp, 8
    jmp label_4
# label_L
label_21:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L86
# i_func_label_L
    nop
    align 8
label_22:
# func_line_I
# i_func_info_IaaI
# erts_trace_cleaner:send_clean_req/1
    call L35
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x7B, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_23:
# i_breakpoint_trampoline
    short jmp L87
.db 0x90
    call L37
L87:
# i_test_yield
    lea rdx, qword ptr [label_23+24]
    dec r14d
    long jle L38
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L88
    mov ecx, 1
    call 139636653423200
L88:
# line_I
# call_light_bif_be
    align 4
L89:
L90:
    long mov rcx, 9223372036854775807
    mov rax, 94068435929808
    lea rdx, qword ptr [L89]
# BIF: erts_trace_cleaner:send_trace_clean_signal/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_25
    cmp rsi, 75
    je label_24
    jmp label_26
# label_L
label_24:
# i_move_sd
    mov qword ptr [rbx], 31
# deallocate_t
# return
    dec r14d
    jl L56
    ret
# label_L
label_25:
# i_move_sd
    mov qword ptr [rbx], 15
# deallocate_t
# return
    dec r14d
    jl L56
    ret
# label_L
label_26:
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L86
# i_func_label_L
    nop
    align 8
label_27:
# func_line_I
# i_func_info_IaaI
# erts_trace_cleaner:check/0
    call L35
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x17, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
check/0:
# i_breakpoint_trampoline
    short jmp L91
.db 0x90
    call L37
L91:
# call_bif_mfa_aaI
# HBIF: erts_trace_cleaner:check/0
L92:
    lea rsi, qword ptr [check/0-24]
    lea rdx, qword ptr [L92]
    mov rcx, 94068435929552
    jmp L93
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L94
    mov ecx, 1
    call 139636653423200
L94:
# call_light_bif_be
    align 4
L95:
L96:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L95]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_29:
# func_line_I
# i_func_info_IaaI
# erts_trace_cleaner:send_trace_clean_signal/1
    call L35
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x17, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
send_trace_clean_signal/1:
# i_breakpoint_trampoline
    short jmp L97
.db 0x90
    call L37
L97:
# call_bif_mfa_aaI
# HBIF: erts_trace_cleaner:send_trace_clean_signal/1
L98:
    lea rsi, qword ptr [send_trace_clean_signal/1-24]
    lea rdx, qword ptr [L98]
    mov rcx, 94068435929808
    jmp L93
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L99
    mov ecx, 1
    call 139636653423200
L99:
# call_light_bif_be
    align 4
L100:
L101:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L100]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_31:
# func_line_I
# i_func_info_IaaI
# erts_trace_cleaner:module_info/0
    call L35
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L102
.db 0x90
    call L37
L102:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L38
    align 4
# i_move_sd
    mov qword ptr [rbx], 71371
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L103
    mov ecx, 1
.db 0x90
    call 139636653423200
L103:
# call_light_bif_be
    align 4
L104:
L105:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L104]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L56
    ret
# i_func_label_L
    align 8
label_33:
# func_line_I
# i_func_info_IaaI
# erts_trace_cleaner:module_info/1
    call L35
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L106
.db 0x90
    call L37
L106:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L38
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 71371
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L107
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L107:
# call_light_bif_be
    align 4
L108:
L109:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L108]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L56
    ret
# int_code_end
L110:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L86:
    jmp 139636653427776
L74:
    jmp 139636653426736
L56:
    jmp 139636653422960
L54:
    jmp 139636653427727
L93:
    jmp 139636653421752
L60:
    jmp 139636653420712
L53:
    jmp 139636653427784
L38:
    jmp 139636653426040
L64:
    jmp 139636653427096
L37:
    jmp 139636653424496
L35:
    jmp 139636653424856
.section .rodata {#1}
md5:
.db 0x38, 0x6A, 0x3E, 0x9A, 0x17, 0x08, 0x34, 0xC3, 0x6D, 0xA7, 0x48, 0x8F, 0x1B, 0x55, 0xBC, 0x73
.section .text {#0}
