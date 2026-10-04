    align 8
L55:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# logger_backend:log_allowed/3
    call L56
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x2E, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
log_allowed/3:
# i_breakpoint_trampoline
    short jmp L57
.db 0x90
    call L58
L57:
# i_test_yield
    lea rdx, qword ptr [log_allowed/3+24]
    dec r14d
    long jle L59
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx+16]
    rex test dil, 1
    jne label_8
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_8
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L60
    mov ecx, 3
.db 0x90
    call 139636653423200
L60:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx+16]
    mov esi, 269643
    mov rdx, -1995863988607837803
    call L61
    jne label_3
    mov qword ptr [rbx+16], rax
# jump_f
    jmp label_4
# label_L
label_3:
# i_move_sd
    mov qword ptr [rbx+16], 59
# label_L
label_4:
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx+24], r11
# i_move_sd
    mov qword ptr [rbx], 149707
# line_I
# i_call_f
.db 0x66, 0x90
    call apply_filters/4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 43019
    jne label_5
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L62
    ret
# label_L
label_5:
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rsp]
    mov esi, 401547
    mov rdx, -1111263569568813196
    call L61
    jne label_6
    mov qword ptr [rbx+8], rax
# jump_f
    jmp label_7
# label_L
label_6:
# i_move_sd
    mov qword ptr [rbx+8], 59
# label_L
label_7:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+16], r10
# i_call_last_ft
    add rsp, 16
    jmp call_handlers/3
# label_L
label_8:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L63
    mov ecx, 3
.db 0x90
    call 139636653423200
L63:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 5387
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L64
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L64:
# call_light_bif_be
    align 4
L65:
L66:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L65]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_9:
# func_line_I
# i_func_info_IaaI
# logger_backend:call_handlers/3
    call L56
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x4F, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
call_handlers/3:
# i_breakpoint_trampoline
    short jmp L67
.db 0x90
    call L58
L67:
# i_test_yield
    lea rdx, qword ptr [call_handlers/3+24]
    dec r14d
    long jle L59
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_19
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_19
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 137291
    mov rdx, -5603825691569281913
    call L61
    jne label_19
    mov qword ptr [rbx+24], rax
# is_nonempty_list_fS
    test byte ptr [rbx+8], 2
    jne label_19
# allocate_tt
    lea rdx, qword ptr [r15+112]
    cmp rdx, rsp
    short jbe L68
    mov ecx, 4
.db 0x66, 0x90
    call 139636653423200
L68:
    sub rsp, 80
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    mov ecx, 5
    rep stos qword ptr [rdi], rax
    mov qword ptr [rsp+72], rax
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp+56], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+64], r11
# get_list_Sdd
    mov rdi, qword ptr [rbx+8]
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rdi-1], 1
    vmovups xmmword ptr [rsp+40], xmm0
# i_move_sd
    mov rdx, qword ptr [rsp+48]
    mov qword ptr [rbx+8], rdx
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# i_move_sd
    mov rcx, qword ptr [rbx+24]
    mov qword ptr [rbx+16], rcx
# line_I
# i_call_ext_e
L69:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_18
    cmp dword ptr [rsi-2], 128
    jne label_18
    cmp qword ptr [rsi+6], 32075
    jne label_18
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rsp+72], r10
# is_map_fs
# simplified fetching of BEAM register
    mov rdi, r10
    rex test dil, 1
    jne label_18
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_18
# i_get_map_element_hash_fScWS
# simplified fetching of BEAM register
    mov rdi, r10
    mov esi, 27723
    mov rdx, -4581473350255011525
    call L61
    jne label_18
    mov qword ptr [rsp+32], rax
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rsp+72]
    mov esi, 269643
    mov rdx, -1995863988607837803
    call L61
    jne label_11
    mov qword ptr [rbx+16], rax
# jump_f
    jmp label_12
# label_L
label_11:
# i_move_sd
    mov qword ptr [rbx+16], 59
# label_L
label_12:
# i_move_sd
    mov r10, qword ptr [rsp+64]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+72]
    mov qword ptr [rbx+24], r11
# i_move_sd
    mov rdx, qword ptr [rsp+48]
    mov qword ptr [rbx], rdx
# line_I
# i_call_f
    call apply_filters/4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+24], r10
# is_ne_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 43019
    je label_18
# i_move_sd
    mov r11, qword ptr [rsp+72]
    mov qword ptr [rbx+8], r11
# init_yregs_I
    mov qword ptr [rsp+72], 59
# i_move_sd
L70:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L71:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# catch_yf
    inc qword ptr [r13+256]
L72:
    mov eax, 2147483647
    mov qword ptr [rsp+72], rax
# i_move_sd
    mov r10, qword ptr [rsp+32]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov qword ptr [rbx+24], 56651
# i_move_sd
    mov rdx, qword ptr [rsp+24]
    mov qword ptr [rbx], rdx
# line_I
# apply_t
    align 4
L74:
    mov edx, 2
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    xor ecx, ecx
    xor r8d, r8d
    call 94068435489472
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    short jne L73
    lea rsi, qword ptr [L74]
    mov rcx, 94068445024480
    push rsi
    jmp L75
L73:
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# try_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+72], 59
# jump_f
    jmp label_18
# label_L
label_13:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp+72], r10
# i_move_sd
    mov r11, qword ptr [rsp+48]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L76:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_16
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_16
    cmp edi, 128
    jne label_22
    cmp qword ptr [rsi+6], 779
    jne label_22
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rsp+72], r10
# i_is_tagged_tuple_fsAa
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_14
    cmp dword ptr [rsi-2], 128
    jne label_14
    cmp qword ptr [rsi+6], 88651
    jne label_14
# jump_f
    jmp label_18
# label_L
label_14:
# i_move_sd
    mov qword ptr [rbx+8], 204619
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    mov qword ptr [rsp+32], rax
    mov qword ptr [rsp+48], rax
# i_move_sd
    mov qword ptr [rbx], 81611
# line_I
# i_call_ext_e
L77:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_18
    cmp rsi, 75
    je label_15
    jmp label_20
# label_L
label_15:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L78
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L78:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 36747
    mov rdi, qword ptr [rsp+72]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
L79:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
L80:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r10, qword ptr [rsp+24]
    mov qword ptr [rbx+16], r10
# init_yregs_I
    mov eax, 59
    mov qword ptr [rsp+24], rax
    mov qword ptr [rsp+72], rax
# i_move_sd
    mov qword ptr [rbx], 81611
# line_I
# i_call_ext_e
L81:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# jump_f
    jmp label_18
# label_L
label_16:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_22
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L82
    xor ecx, ecx
.db 0x90
    call 139636653423200
L82:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 413707
    mov rdi, qword ptr [rsp+48]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 779
# line_I
# i_call_ext_e
L83:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx+8], 204619
# i_move_sd
    mov qword ptr [rbx], 81611
# line_I
# i_call_ext_e
L84:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_18
    cmp rsi, 75
    je label_17
    jmp label_21
# label_L
label_17:
# i_move_sd
    mov r10, qword ptr [rsp+72]
    mov qword ptr [rbx], r10
# build_stacktrace
# simplified fetching of BEAM register
    mov rsi, r10
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435483376
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov qword ptr [rbx], rax
# init_yregs_I
    mov qword ptr [rsp+72], 59
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call filter_stacktrace/1
# test_heap_It
    lea rdx, qword ptr [r15+280]
    cmp rdx, rsp
    short jbe L85
    mov ecx, 1
.db 0x90
    call 139636653423200
L85:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rsp+48]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp+32]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [r15+8], xmm0
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r11
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 36747
# simplified fetching of BEAM register
    mov rdi, r11
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea rdx, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], rdx
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, rdx
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 85387
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+16], r11
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, r11
    mov qword ptr [r15], rdi
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 413771
    mov rdi, qword ptr [rsp+24]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea rdx, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+16], rdx
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, rdx
    mov qword ptr [r15], rdi
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 403915
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r11
# put_cons_ss
# (putting and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [r15], xmm0
    lea rsi, qword ptr [r15+1]
# append_cons_Is
L86:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
L87:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r10, qword ptr [rsp+24]
    mov qword ptr [rbx+16], r10
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    mov ecx, 5
    rep stos qword ptr [rdi], rax
    mov qword ptr [rsp+48], rax
# i_move_sd
    mov qword ptr [rbx], 81611
# line_I
# i_call_ext_e
L88:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# label_L
label_18:
# i_move_sd
    mov r10, qword ptr [rsp+40]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+56]
    mov qword ptr [rbx+16], r11
# i_move_sd
    mov rdx, qword ptr [rsp+64]
    mov qword ptr [rbx], rdx
# i_call_last_ft
    add rsp, 80
    jmp call_handlers/3
# label_L
label_19:
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    jne label_9
# i_move_sd
    mov qword ptr [rbx], 32075
# return
    dec r14d
    jl L62
    ret
# label_L
label_20:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L89
# label_L
label_21:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L89
# label_L
label_22:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L89
# i_func_label_L
    nop
    align 8
label_23:
# func_line_I
# i_func_info_IaaI
# logger_backend:apply_filters/4
    call L56
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x50, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
apply_filters/4:
# i_breakpoint_trampoline
    short jmp L90
.db 0x90
    call L58
L90:
# i_test_yield
    lea rdx, qword ptr [apply_filters/4+24]
    dec r14d
    long jle L59
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L91
    mov ecx, 4
    call 139636653423200
L91:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rsp+8], r11
# i_move_sd
    mov qword ptr [rbx+24], 21515
# line_I
# i_call_f
.db 0x66, 0x90
    call do_apply_filters/4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 21515
    jne label_26
# line_I
# bif_map_get_jssd
    mov rdi, qword ptr [rsp]
    mov esi, 269387
# skipped test for map for known map argument
    call L93
    je L92
    mov rdi, qword ptr [rsp]
    mov esi, 269387
    call 139636653423920
L92:
    mov qword ptr [rbx], rax
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, rax
    cmp rsi, 43019
    je label_26
    cmp rsi, 56651
    je label_25
    jmp label_27
# label_L
label_25:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L62
    ret
# label_L
label_26:
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L62
    ret
# label_L
label_27:
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L89
# i_func_label_L
    nop
    align 8
label_28:
# func_line_I
# i_func_info_IaaI
# logger_backend:do_apply_filters/4
    call L56
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x50, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_apply_filters/4:
# i_breakpoint_trampoline
    short jmp L94
.db 0x90
    call L58
L94:
# i_test_yield
    lea rdx, qword ptr [do_apply_filters/4+24]
    dec r14d
    long jle L59
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx+16]
    test al, 2
    jne label_43
# (moving head and tail together)
    vmovups xmm0, xmmword ptr [rax-1]
    vmovups xmmword ptr [rbx+32], xmm0
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+32]
    rex test sil, 1
    short jne label_28
    cmp dword ptr [rsi-2], 128
    short jne label_28
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+48], r10
# i_is_tuple_of_arity_fsA
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    short jne label_28
    cmp dword ptr [rsi-2], 128
    jne label_28
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r11
# i_get_tuple_element_sPS
    mov rdx, qword ptr [rsi+14]
    mov qword ptr [rbx+48], rdx
# allocate_tt
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L95
    mov ecx, 7
.db 0x90
    call 139636653423200
L95:
    sub rsp, 48
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rsp+16], r10
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+24], xmm0
# catch_yf
    inc qword ptr [r13+256]
L96:
    mov eax, 2147483647
    mov qword ptr [rsp+40], rax
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rbx+48]
    mov qword ptr [rbx+8], r11
# line_I
# i_call_fun_t
    mov rcx, qword ptr [rbx+16]
    mov edx, 532
    mov rdi, 139636653423680
    lea r8, qword ptr [L97]
    test ecx, 1
    short jne L97
    cmp word ptr [rcx-2], dx
    short jne L97
    mov rax, qword ptr [rcx+6]
    mov rdi, qword ptr [rax+r12*8]
L97:
    call rdi
.db 0x0F, 0x1F, 0x00
    call rdi
# try_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+40], 59
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_38
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_38
# i_get_map_elements_fsI
.section .rodata {#1}
L100:
    align 8
.db 0xCB, 0x68, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x23, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0xA6, 0x11, 0x9D, 0x24, 0xB9, 0xD8, 0xB9, 0x8D
    align 8
.db 0x0B, 0x07, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x33, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x2C, 0x1A, 0x52, 0xD9, 0x89, 0xAE, 0x4F, 0x8D
    align 8
.db 0x4B, 0x18, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x13, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x87, 0x24, 0xCE, 0x4E, 0x39, 0x36, 0x3B, 0xB2
.section .text {#0}
# skipped fetching of BEAM register
# simplified multi-element lookup
    mov eax, dword ptr [rdi-2]
    and al, 252
    cmp al, 44
    jne L98
    mov eax, dword ptr [rdi+6]
    mov rsi, qword ptr [rdi+14]
L101:
    dec eax
    jl label_41
    cmp qword ptr [rsi+rax*8+6], 137291
    short jne L101
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+8], rdx
L102:
    dec eax
    jl label_41
    cmp qword ptr [rsi+rax*8+6], 132875
    short jne L102
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+24], rdx
L103:
    dec eax
    jl label_41
    cmp qword ptr [rsi+rax*8+6], 26827
    short jne L103
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+16], rdx
    short jmp L99
L98:
    mov ecx, 3
    lea r8, qword ptr [L100]
    mov rdx, rsp
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rbx
    call 94068434772192
    mov rsp, rbp
    test rax, rax
    je label_41
L99:
# is_atom_fs
    mov rax, qword ptr [rbx+8]
    and al, 63
    cmp al, 11
    jne label_41
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+24]
    rex test sil, 1
    jne label_33
    cmp dword ptr [rsi-2], 128
    jne label_33
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# is_list_fs
# simplified fetching of BEAM register
    mov rax, r10
    cmp rax, 59
    short je L104
    test al, 2
    jne label_30
L104:
# jump_f
    jmp label_32
# label_L
label_30:
# is_binary_fs
    mov rdi, qword ptr [rbx+8]
    rex test dil, 1
    jne label_31
    mov rax, qword ptr [rdi+6]
    mov esi, qword ptr [rdi-2]
    cmp esi, 292
    short jne L105
    mov rax, qword ptr [rdi+22]
    sub rax, qword ptr [rdi+14]
L105:
    shl eax, 29
    and esi, 59
    or esi, eax
    cmp esi, 32
    jne label_31
# jump_f
    jmp label_32
# label_L
label_31:
# is_atom_fs
    mov rax, qword ptr [rbx+8]
    and al, 63
    cmp al, 11
    jne label_33
# label_L
label_32:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+24]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# is_list_fs
# simplified fetching of BEAM register
    mov rax, r10
    cmp rax, 59
    short je L106
    test al, 2
    jne label_33
L106:
# jump_f
    jmp label_37
# label_L
label_33:
# bif_element_jssd
    mov rsi, qword ptr [rbx+24]
    rex test sil, 1
    jne label_41
    mov eax, dword ptr [rsi-2]
    cmp eax, 64
    jb label_41
    and al, 63
    jne label_41
    mov rax, qword ptr [rsi+6]
    mov qword ptr [rbx+8], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 145675
    jne label_35
# bif_element_jssd
    mov rsi, qword ptr [rbx+24]
# skipped tuple test since source is always a tuple
    cmp dword ptr [rsi-2], 128
    jb label_41
    mov rax, qword ptr [rsi+14]
    mov qword ptr [rbx+32], rax
# is_map_fs
# simplified fetching of BEAM register
    mov rdi, rax
    rex test dil, 1
    jne label_34
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_34
# jump_f
    jmp label_37
# label_L
label_34:
# is_list_fs
    mov rax, qword ptr [rbx+32]
    cmp rax, 59
    short je L107
    test al, 2
    jne label_35
L107:
# is_nonempty_list_get_hd_fSd
# skipped fetching of BEAM register
    test al, 2
    jne label_41
    mov rsi, qword ptr [rax-1]
    mov qword ptr [rbx+32], rsi
# i_is_tuple_fs
# skipped fetching of BEAM register
    rex test sil, 1
    jne label_35
    test byte ptr [rsi-2], 63
    jne label_35
# jump_f
    jmp label_37
# label_L
label_35:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 62923
    jne label_41
# bif_element_jssd
    mov rsi, qword ptr [rbx+24]
# skipped tuple test since source is always a tuple
    cmp dword ptr [rsi-2], 128
    jb label_41
    mov rax, qword ptr [rsi+14]
    mov qword ptr [rbx+8], rax
# is_list_fs
# skipped fetching of BEAM register
    cmp rax, 59
    short je L108
    test al, 2
    jne label_36
L108:
# jump_f
    jmp label_37
# label_L
label_36:
# is_binary_fs
    mov rdi, qword ptr [rbx+8]
    rex test dil, 1
    jne label_41
    mov rax, qword ptr [rdi+6]
    mov esi, qword ptr [rdi-2]
    cmp esi, 292
    short jne L109
    mov rax, qword ptr [rdi+22]
    sub rax, qword ptr [rdi+14]
L109:
    shl eax, 29
    and esi, 59
    or esi, eax
    cmp esi, 32
    jne label_41
# label_L
label_37:
# is_map_fs
    mov rdi, qword ptr [rbx+16]
    rex test dil, 1
    jne label_41
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_41
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov qword ptr [rbx+24], 56651
# i_move_sd
    mov rdx, qword ptr [rsp+32]
    mov qword ptr [rbx], rdx
# i_call_last_ft
    add rsp, 48
    jmp do_apply_filters/4
# label_L
label_38:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 21515
    je label_40
    cmp rsi, 43019
    je label_39
    jmp label_41
# label_L
label_39:
# deallocate_t
    add rsp, 48
# return
    dec r14d
    jl L62
    ret
# label_L
label_40:
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp+8]
    vmovups xmmword ptr [rbx+16], xmm0
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+24], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 48
    jmp do_apply_filters/4
# label_L
label_41:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L110
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L110:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 395915
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+24], r10
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+24], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 48
    jmp handle_filter_failed/4
# label_L
label_42:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rsp+40], r11
# i_move_sd
    mov rdx, qword ptr [rbx+16]
    mov qword ptr [rbx], rdx
# build_stacktrace
# simplified fetching of BEAM register
    mov rsi, rdx
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435483376
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov qword ptr [rbx], rax
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rsp+8], r10
# i_trim_t
    add rsp, 8
# line_I
# i_call_f
.db 0x66, 0x90
    call filter_stacktrace/1
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L111
    mov ecx, 1
    call 139636653423200
L111:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp+32]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx+24], r10
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+16], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 40
    jmp handle_filter_failed/4
# label_L
label_43:
# is_nil_fS
    cmp byte ptr [rbx+16], 59
    jne label_28
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 56651
    jne label_44
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L62
    ret
# label_L
label_44:
# i_move_sd
    mov qword ptr [rbx], 21515
# return
    dec r14d
    jl L62
    ret
# i_func_label_L
    align 8
label_45:
# func_line_I
# i_func_info_IaaI
# logger_backend:handle_filter_failed/4
    call L56
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x51, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_filter_failed/4:
# i_breakpoint_trampoline
    short jmp L112
.db 0x90
    call L58
L112:
# i_test_yield
    lea rdx, qword ptr [handle_filter_failed/4+24]
    dec r14d
    long jle L59
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L113
    mov ecx, 4
    call 139636653423200
L113:
    sub rsp, 40
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+16], 1
    vmovups xmmword ptr [rsp+8], xmm0
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+24], xmm0
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rbx], r11
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx+8], r10
# line_I
# i_call_ext_e
L114:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_48
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L115
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L115:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 414027
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov qword ptr [rbx], 779
# line_I
# i_call_ext_e
L116:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx+8], 204619
# i_move_sd
    mov qword ptr [rbx], 81611
# line_I
# i_call_ext_e
L117:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_48
    cmp rsi, 75
    je label_47
    jmp label_49
# label_L
label_47:
# test_heap_It
    lea rdx, qword ptr [r15+224]
    cmp rdx, rsp
    short jbe L118
    xor ecx, ecx
    call 139636653423200
L118:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 36747
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 413771
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# put_cons_ss
# (putting and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [r15], xmm0
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 33355
    mov rdi, qword ptr [rsp+24]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r11
# put_cons_ss
# (putting and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [r15], xmm0
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 238091
    mov rdi, qword ptr [rsp+32]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# put_cons_ss
# (putting and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [r15], xmm0
    lea rsi, qword ptr [r15+1]
# append_cons_Is
L119:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
L120:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx+16], r10
# init_yregs_I
    mov eax, 59
    lea rdi, qword ptr [rsp+8]
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# i_move_sd
    mov qword ptr [rbx], 81611
# i_call_ext_e
L121:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# label_L
label_48:
# i_move_sd
    mov qword ptr [rbx], 21515
# deallocate_t
    add rsp, 40
# return
    dec r14d
    jl L62
    ret
# label_L
label_49:
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L89
# i_func_label_L
    nop
    align 8
label_50:
# func_line_I
# i_func_info_IaaI
# logger_backend:filter_stacktrace/1
    call L56
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x30, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
filter_stacktrace/1:
# i_breakpoint_trampoline
    short jmp L122
.db 0x90
    call L58
L122:
# i_test_yield
    lea rdx, qword ptr [filter_stacktrace/1+24]
    dec r14d
    long jle L59
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 204619
# i_call_ext_only_e
L123:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_52:
# func_line_I
# i_func_info_IaaI
# logger_backend:module_info/0
    call L56
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L124
.db 0x90
    call L58
L124:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L59
    align 4
# i_move_sd
    mov qword ptr [rbx], 204619
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L125
    mov ecx, 1
.db 0x90
    call 139636653423200
L125:
# call_light_bif_be
    align 4
L126:
L127:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L126]
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
label_54:
# func_line_I
# i_func_info_IaaI
# logger_backend:module_info/1
    call L56
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L128
.db 0x90
    call L58
L128:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L59
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 204619
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L129
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L129:
# call_light_bif_be
    align 4
L130:
L131:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L130]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L62
    ret
# int_code_end
L132:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L89:
    jmp 139636653427776
L75:
    jmp 139636653427784
L62:
    jmp 139636653422960
L61:
    jmp 139636653425144
L93:
    jmp 139636653424896
L59:
    jmp 139636653426040
L58:
    jmp 139636653424496
L56:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0xC7, 0x5A, 0x36, 0xF9, 0x21, 0x2A, 0xA7, 0x95, 0x05, 0xFC, 0x8A, 0xA3, 0x0D, 0xB7, 0x8B, 0xA1, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x30, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x6C, 0x6F, 0x67, 0x67, 0x65, 0x72, 0x5F, 0x62, 0x61, 0x63, 0x6B, 0x65, 0x6E, 0x64, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0xA1, 0x8B, 0xB7, 0x0D, 0xA3, 0x8A, 0xFC, 0x05, 0x95, 0xA7, 0x2A, 0x21, 0xF9, 0x36, 0x5A, 0xC7
.section .text {#0}
