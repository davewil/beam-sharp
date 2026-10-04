    align 8
L56:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:start/0
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xA7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start/0:
# i_breakpoint_trampoline
    short jmp L58
.db 0x90
    call L59
L58:
# i_test_yield
    lea rdx, qword ptr [start/0+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L61
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L61:
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx], 45387
# line_I
# call_light_bif_be
    align 4
L62:
L63:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L62]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx+16], 15
# i_move_sd
L64:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx+24], 59
# i_move_sd
    mov qword ptr [rbx], 907
# i_call_last_ft
    jmp label_4
# i_func_label_L
    align 8
label_3:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:msg_loop/4
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x79, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_4:
# i_breakpoint_trampoline
    short jmp L65
.db 0x90
    call L59
L65:
# i_test_yield
    lea rdx, qword ptr [label_4+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L66
    mov ecx, 4
    call 139636653423200
L66:
    sub rsp, 56
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+16], 1
    vmovups xmmword ptr [rsp+24], xmm0
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+40], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 907
    jne label_5
# i_move_sd
    mov qword ptr [rsp+16], 960015
# jump_f
    jmp label_6
# label_L
label_5:
# i_move_sd
    mov qword ptr [rsp+16], 395
# label_L
label_6:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+6], 1
    vmovups xmmword ptr [rsp], xmm0
# aligned_label_Lt
    align 4
label_7:
# i_loop_rec_f
    align 4
L67:
    lea rdi, qword ptr [L67]
    lea rsi, qword ptr [label_26]
    call 139636653425768
# i_is_tuple_fs
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_24
    test byte ptr [rsi-2], 63
    jne label_24
# i_select_tuple_arity_SfI
# skipped fetching of BEAM register
# skipped box test since argument is always boxed
    mov esi, dword ptr [rsi-2]
# simplified tuple test since the source is always a tuple when boxed
    cmp esi, 192
    je label_9
    cmp esi, 256
    je label_8
    jne label_25
# label_L
label_8:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 79499
    jne label_25
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
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rbx+8], xmm0
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx], r10
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rbx+8], xmm0
# swap_dd
# simplified fetching of BEAM register
    mov rdi, r10
    mov rsi, qword ptr [rbx+16]
    mov qword ptr [rbx+16], rdi
    mov qword ptr [rbx], rsi
# i_trim_t
    add rsp, 24
# line_I
# i_call_f
    call label_51
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
label_9:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+24], r10
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 10699
    je label_15
    cmp rsi, 82571
    je label_10
    jmp label_25
# label_L
label_10:
# is_pid_fs
    mov rdi, qword ptr [rbx+24]
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L68
    test al, 1
    jne label_11
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_11
L68:
# jump_f
    jmp label_12
# label_L
label_11:
# is_reference_fs
    mov rdi, qword ptr [rbx+24]
    rex test dil, 1
    jne label_25
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 16
    short je L69
    cmp al, 56
    jne label_25
L69:
# label_L
label_12:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+16], 1
    vmovups xmmword ptr [rbx], xmm0
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
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rsp+8], 15
    jne label_13
# i_move_sd
    mov qword ptr [rbx+16], 162123
# jump_f
    jmp label_14
# label_L
label_13:
# i_move_sd
    mov qword ptr [rbx+16], 162187
# label_L
label_14:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L70
    mov ecx, 3
.db 0x90
    call 139636653423200
L70:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx+8]
    vmovups xmmword ptr [r15+8], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_trim_t
    add rsp, 24
# line_I
# send
    align 4
L71:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L71]
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
# label_L
label_15:
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+16]
    rex test sil, 1
    jne label_25
    cmp dword ptr [rsi-2], 192
    jne label_25
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+32], r11
# i_get_tuple_element_sPS
    mov rdx, qword ptr [rsi+22]
    mov qword ptr [rbx+16], rdx
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r11, 22283
    jne label_16
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 32075
    jne label_20
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+48]
# simplified fetching of BEAM register
    mov rdi, r10
    cmp rdi, rsi
    short je L72
    mov eax, edi
    or eax, esi
    test al, 1
    jne label_25
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_25
L72:
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
    short je L74
    mov rax, rsi
    sub rax, 16
    short jno L73
L74:
    call L75
L73:
    mov qword ptr [rbx+8], rax
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+16], r10
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    mov qword ptr [rsp+40], rax
# i_move_sd
    mov r10, qword ptr [rsp+48]
    mov qword ptr [rbx], r10
# i_call_f
.db 0x66, 0x90
    call label_33
# is_ne_exact_fss
# optimized non-equality test with {0,none}
L76:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    call L77
    je label_17
# i_move_sd
    mov r10, qword ptr [rsp+32]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov rdx, qword ptr [rsp+24]
    mov qword ptr [rbx+24], rdx
# i_move_sd
    mov rcx, qword ptr [rsp+48]
    mov qword ptr [rbx], rcx
# i_call_last_ft
    add rsp, 56
    jmp label_4
# label_L
label_16:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 32075
    jne label_20
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+48]
    mov rdi, qword ptr [rbx+8]
    cmp rdi, rsi
    short je L78
    mov eax, edi
    or eax, esi
    test al, 1
    jne label_25
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_25
L78:
# is_nil_fS
    cmp byte ptr [rsp+24], 59
    jne label_19
# is_ne_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+32], 22283
    je label_21
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
    short je L80
    mov rax, rsi
    sub rax, 16
    short jno L79
L80:
    call L75
L79:
    mov qword ptr [rbx+8], rax
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+16], r10
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    mov qword ptr [rsp+40], rax
# i_move_sd
    mov r10, qword ptr [rsp+48]
    mov qword ptr [rbx], r10
# i_call_f
.db 0x90
    call label_33
# is_eq_exact_fss
# optimized equality test with {0,none}
L81:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    call L77
    jne label_18
# label_L
label_17:
# i_call_last_ft
    add rsp, 56
    jmp label_28
# label_L
label_18:
# line_I
# i_minus_ssjd
    mov rsi, qword ptr [rsp+32]
    mov edx, 31
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L83
    mov rax, rsi
    sub rax, 16
    short jno L82
L83:
    call L75
L82:
    mov qword ptr [rbx+16], rax
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+24], 59
# i_move_sd
    mov r11, qword ptr [rsp+48]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 56
    jmp label_4
# label_L
label_19:
# is_ne_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+32], 22283
    je label_21
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
# get_list_Sdd
    mov rdi, qword ptr [rsp+24]
    mov rsi, qword ptr [rdi-1]
    mov rdx, qword ptr [rdi+7]
    mov qword ptr [rbx], rsi
    mov qword ptr [rsp+40], rdx
# load_tuple_ptr_s
# skipped fetching of BEAM register
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+48]
    mov qword ptr [rbx+8], r11
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rsp+16], xmm0
# i_trim_t
    add rsp, 16
# line_I
# i_call_f
.db 0x90
    call label_45
# line_I
# i_minus_ssjd
    mov rsi, qword ptr [rsp]
    mov edx, 31
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L85
    mov rax, rsi
    sub rax, 16
    short jno L84
L85:
    call L75
L84:
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L86
    mov ecx, 1
    call 139636653423200
L86:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp+16]
    vmovups xmmword ptr [rbx+16], xmm0
# i_move_sd
    mov r11, qword ptr [rsp+32]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 40
    jmp label_4
# label_L
label_20:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+32], 22283
    jne label_23
# label_L
label_21:
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+48]
    mov rdi, qword ptr [rbx+8]
    cmp rdi, rsi
    short je L87
    mov eax, edi
    or eax, esi
    test al, 1
    jne label_25
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_25
L87:
# is_ge_fss
    mov rsi, qword ptr [rsp+32]
    mov edi, 31
# simplified small test for known integer
    rex test sil, 1
    short jne L89
    mov eax, dword ptr [rsi-2]
    and al, 63
    cmp al, 12
    short jmp L90
L89:
    cmp rdi, rsi
L88:
L90:
    jl label_22
L91:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+16], 1
    vmovups xmmword ptr [rbx], xmm0
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
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rbx], r11
# i_move_sd
    mov rdx, qword ptr [rsp+48]
    mov qword ptr [rbx+8], rdx
# i_trim_t
    add rsp, 24
# line_I
# i_call_f
    call label_45
# line_I
# i_plus_ssjd
    mov rsi, qword ptr [rsp+8]
    mov edx, 31
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L93
# skipped overflow test because the result is always small
    lea rax, qword ptr [rsi+rdx-15]
    short jmp L92
L93:
    call L94
L92:
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
label_22:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp+16], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rsp+40], r11
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
    vmovups xmmword ptr [rbx+8], xmm0
# i_trim_t
    add rsp, 16
# i_move_sd
    mov r10, qword ptr [rsp+32]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call label_33
# test_heap_It
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L95
    mov ecx, 1
    call 139636653423200
L95:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp+24]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov rdx, qword ptr [rsp+32]
    mov qword ptr [rbx], rdx
# i_call_last_ft
    add rsp, 40
    jmp label_4
# label_L
label_23:
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+48]
    mov rdi, qword ptr [rbx+8]
    cmp rdi, rsi
    short je L96
    mov eax, edi
    or eax, esi
    test al, 1
    jne label_25
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_25
L96:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L97
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L97:
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
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 162251
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L98:
L99:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091216
    lea rdx, qword ptr [L98]
# BIF: erlang:exit/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_24:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 10699
    jne label_25
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rsp+8], 15
    jne label_25
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
    add rsp, 56
    jmp label_28
# label_L
label_25:
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
    vpermilpd xmm0, xmmword ptr [rsp+24], 1
    vmovups xmmword ptr [rbx+16], xmm0
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+40], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 56
    jmp label_4
# aligned_label_Lt
    align 4
label_26:
# wait_timeout_locked_sf
    mov rsi, qword ptr [rsp+16]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rdx, qword ptr [L101]
    call 94068434776064
    mov rsp, rbp
    cmp rax, 1
    short je L100
    short jl L101
    lea rsi, qword ptr [label_26]
    xor ecx, ecx
    push rsi
    jmp L102
L100:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_7]
    call 94068434775632
    mov rsp, rbp
    jmp L103
    align 4
L101:
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
    mov qword ptr [rbx], 54731
# line_I
# i_call_ext_e
L104:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# deallocate_t
    add rsp, 56
# return
    dec r14d
    jl L105
    ret
# i_func_label_L
    align 8
label_27:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:switch_area/0
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x7A, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_28:
# i_breakpoint_trampoline
    short jmp L106
.db 0x90
    call L59
L106:
# i_test_yield
    lea rdx, qword ptr [label_28+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L107
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L107:
    sub rsp, 16
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# line_I
# call_light_bif_be
    align 4
L108:
L109:
    long mov rcx, 9223372036854775807
    mov rax, 94068435512736
    lea rdx, qword ptr [L108]
# BIF: erts_literal_area_collector:release_area_switch/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_30
    cmp rsi, 75
    je label_29
    jmp label_31
# label_L
label_29:
# call_light_bif_be
    align 4
L110:
L111:
    long mov rcx, 9223372036854775807
    mov rax, 94068435960192
    lea rdx, qword ptr [L110]
# BIF: erlang:make_ref/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# line_I
# i_call_ext_e
L112:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov qword ptr [rbx], 33227
# line_I
# call_light_bif_be
    align 4
L113:
L114:
    long mov rcx, 9223372036854775807
    mov rax, 94068435859296
    lea rdx, qword ptr [L113]
# BIF: erlang:system_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rbx+16], r11
# i_move_sd
    mov rdx, qword ptr [rsp]
    mov qword ptr [rbx], rdx
# i_trim_t
    add rsp, 8
# line_I
# i_call_f
    call label_38
# i_move_sd
    mov qword ptr [rbx+16], 15
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+24], 59
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp label_4
# label_L
label_30:
# i_move_sd
    mov qword ptr [rbx+16], 15
# i_move_sd
L115:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx+24], 59
# i_move_sd
    mov qword ptr [rbx], 907
# i_call_last_ft
    add rsp, 16
    jmp label_4
# label_L
label_31:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L116
# i_func_label_L
    nop
    align 8
label_32:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:check_send_copy_req/3
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x7A, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_33:
# i_breakpoint_trampoline
    short jmp L117
.db 0x90
    call L59
L117:
# i_test_yield
    lea rdx, qword ptr [label_33+24]
    dec r14d
    long jle L60
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 1291
    jne label_34
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L118
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L118:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+8], rdi
    mov qword ptr [r15+16], 1291
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L105
    ret
# label_L
label_34:
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L119
    mov ecx, 3
    call 139636653423200
L119:
    sub rsp, 24
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L120:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_is_tuple_of_arity_ff_ffsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_35
    mov eax, dword ptr [rsi-2]
    test al, 63
    jne label_35
    cmp eax, 128
    jne label_36
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rsp], r11
# i_move_sd
    mov qword ptr [rbx+16], 22283
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# i_move_sd
    mov rdx, qword ptr [rsp+16]
    mov qword ptr [rbx+8], rdx
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp+16], r11
# i_trim_t
    add rsp, 8
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call label_45
# line_I
# i_plus_ssjd
    mov rsi, qword ptr [rsp]
    mov edx, 31
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L122
    lea rax, qword ptr [rsi-15]
    add rax, rdx
    short jno L121
L122:
    call L94
L121:
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L123
    mov ecx, 1
    call 139636653423200
L123:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L105
    ret
# label_L
label_35:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 1291
    jne label_36
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L124
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L124:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+8], rdi
    mov qword ptr [r15+16], 1291
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 24
# return
    dec r14d
    jl L105
    ret
# label_L
label_36:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L116
# i_func_label_L
    nop
    align 8
label_37:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:send_copy_reqs/3
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x7A, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_38:
# i_breakpoint_trampoline
    short jmp L125
.db 0x90
    call L59
L125:
# i_test_yield
    lea rdx, qword ptr [label_38+24]
    dec r14d
    long jle L60
    align 4
# i_move_sd
    mov qword ptr [rbx+24], 15
# i_call_only_f
    jmp label_40
# i_func_label_L
    align 8
label_39:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:send_copy_reqs/4
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x7A, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_40:
# i_breakpoint_trampoline
    short jmp L126
.db 0x90
    call L59
L126:
# i_test_yield
    lea rdx, qword ptr [label_40+24]
    dec r14d
    long jle L60
    align 4
# is_ge_fss
    mov rsi, qword ptr [rbx+16]
    mov rdi, qword ptr [rbx+24]
    cmp rdi, rsi
    short je L130
    mov eax, edi
    and eax, esi
    and al, 15
    cmp al, 15
    short jne L127
L128:
    cmp rdi, rsi
    short jmp L129
L127:
    call L131
L129:
    jl label_41
L130:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L132
    mov ecx, 4
.db 0x90
    call 139636653423200
L132:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx+24]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L105
    ret
# label_L
label_41:
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L133
    mov ecx, 4
.db 0x90
    call 139636653423200
L133:
    sub rsp, 32
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+16], 1
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+24], r10
# line_I
# i_call_ext_e
L134:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_is_tuple_of_arity_ff_ffsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_42
    mov eax, dword ptr [rsi-2]
    test al, 63
    jne label_42
    cmp eax, 128
    jne label_43
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rsp], r11
# i_move_sd
    mov qword ptr [rbx+16], 22283
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# i_move_sd
    mov rdx, qword ptr [rsp+24]
    mov qword ptr [rbx+8], rdx
# line_I
# i_call_f
    call label_45
# line_I
# i_plus_ssjd
    mov rsi, qword ptr [rsp+8]
    mov edx, 31
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L136
    lea rax, qword ptr [rsi-15]
    add rax, rdx
    short jno L135
L136:
    call L94
L135:
    mov qword ptr [rbx+24], rax
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+16], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 32
    jmp label_40
# label_L
label_42:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 1291
    jne label_43
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L137
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L137:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+8], rdi
    mov qword ptr [r15+16], 1291
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 32
# return
    dec r14d
    jl L105
    ret
# label_L
label_43:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L116
# i_func_label_L
    nop
    align 8
label_44:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:send_copy_req/3
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x7A, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_45:
# i_breakpoint_trampoline
    short jmp L138
.db 0x90
    call L59
L138:
# line_I
# i_test_yield
    lea rdx, qword ptr [label_45+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L139
    mov ecx, 3
    call 139636653423200
L139:
# call_light_bif_be
    align 4
L140:
L141:
    long mov rcx, 9223372036854775807
    mov rax, 94068435512512
    lea rdx, qword ptr [L140]
# BIF: erts_literal_area_collector:send_copy_request/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L105
    ret
# i_func_label_L
    align 8
label_46:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:release_area_switch/0
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xD6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
release_area_switch/0:
# i_breakpoint_trampoline
    short jmp L142
.db 0x90
    call L59
L142:
# call_bif_mfa_aaI
# HBIF: erts_literal_area_collector:release_area_switch/0
L143:
    lea rsi, qword ptr [release_area_switch/0-24]
    lea rdx, qword ptr [L143]
    mov rcx, 94068435512736
    jmp L144
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L145
    mov ecx, 1
    call 139636653423200
L145:
# call_light_bif_be
    align 4
L146:
L147:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L146]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_48:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:send_copy_request/3
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xD6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
send_copy_request/3:
# i_breakpoint_trampoline
    short jmp L148
.db 0x90
    call L59
L148:
# call_bif_mfa_aaI
# HBIF: erts_literal_area_collector:send_copy_request/3
L149:
    lea rsi, qword ptr [send_copy_request/3-24]
    lea rdx, qword ptr [L149]
    mov rcx, 94068435512512
    jmp L144
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L150
    mov ecx, 1
    call 139636653423200
L150:
# call_light_bif_be
    align 4
L151:
L152:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L151]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_50:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:change_prio/3
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x36, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_51:
# i_breakpoint_trampoline
    short jmp L153
.db 0x90
    call L59
L153:
# i_test_yield
    lea rdx, qword ptr [label_51+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L154
    mov ecx, 3
    call 139636653423200
L154:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# catch_yf
    inc qword ptr [r13+256]
L155:
    mov eax, 2147483647
    mov qword ptr [rsp+16], rax
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 34955
# line_I
# call_light_bif_be
    align 4
L156:
L157:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L156]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L158
    mov ecx, 1
    call 139636653423200
L158:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# line_I
# send
    align 4
L159:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L159]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# try_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+16], 59
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 24
# return
    dec r14d
    jl L105
    ret
# label_L
label_52:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L160
    xor ecx, ecx
    call 139636653423200
L160:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+8], rdi
    mov qword ptr [r15+16], 779
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# i_trim_t
    add rsp, 24
# line_I
# send
    align 4
L161:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L161]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L105
    ret
# i_func_label_L
    align 8
label_53:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:module_info/0
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L162
.db 0x90
    call L59
L162:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L60
    align 4
# i_move_sd
    mov qword ptr [rbx], 54731
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L163
    mov ecx, 1
.db 0x90
    call 139636653423200
L163:
# call_light_bif_be
    align 4
L164:
L165:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L164]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L105
    ret
# i_func_label_L
    align 8
label_55:
# func_line_I
# i_func_info_IaaI
# erts_literal_area_collector:module_info/1
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0xD5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L166
.db 0x90
    call L59
L166:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L60
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 54731
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L167
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L167:
# call_light_bif_be
    align 4
L168:
L169:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L168]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L105
    ret
# int_code_end
L170:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L105:
    jmp 139636653422960
L103:
    jmp 139636653427727
L144:
    jmp 139636653421752
L131:
    jmp 139636653420712
L102:
    jmp 139636653427784
L116:
    jmp 139636653427776
L77:
    jmp 139636653426424
L75:
    jmp 139636653426736
L60:
    jmp 139636653426040
L94:
    jmp 139636653427096
L59:
    jmp 139636653424496
L57:
    jmp 139636653424856
.section .rodata {#1}
md5:
.db 0x7A, 0xC3, 0x94, 0x2E, 0xD7, 0x4A, 0xB6, 0x7F, 0xBA, 0x1A, 0x27, 0x1C, 0x23, 0xEE, 0xE5, 0x06
.section .text {#0}
