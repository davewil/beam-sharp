    align 8
L38:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# error_handler:undefined_function/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
undefined_function/3:
# i_breakpoint_trampoline
    short jmp L40
.db 0x90
    call L41
L40:
# i_test_yield
    lea rdx, qword ptr [undefined_function/3+24]
    dec r14d
    long jle L42
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L43
    mov ecx, 3
    call 139636653423200
L43:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call ensure_loaded/1
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_5
    cmp dword ptr [rsi-2], 128
    jne label_5
    cmp qword ptr [rsi+6], 27723
    jne label_5
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+16]
# simplified fetching of BEAM register
    mov rdi, r10
    cmp rdi, rsi
    short je L44
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    je label_5
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_5
L44:
# line_I
# i_length_setup_jts
    mov rdi, qword ptr [rsp]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], 15
    mov rdi, qword ptr [rsp]
    mov qword ptr [rbx+16], rdi
# i_length_jtd
    align 4
L45:
    xor esi, esi
    lea rdx, qword ptr [L45]
    call L46
    mov qword ptr [rbx+16], rax
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+8], 1
    vmovups xmmword ptr [rbx], xmm0
# call_light_bif_be
    align 4
L47:
L48:
    long mov rcx, 9223372036854775807
    mov rax, 94068436111984
    lea rdx, qword ptr [L47]
# BIF: erlang:function_exported/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_4
    cmp rsi, 75
    je label_3
    jmp label_6
# label_L
label_3:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# line_I
# i_apply_last_t
    add rsp, 24
    align 4
L50:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    lea rdx, qword ptr [L50]
    xor ecx, ecx
    call 94068435488720
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    short jne L49
    lea rsi, qword ptr [L50]
    mov rcx, 94068445024480
    push rsi
    jmp L51
L49:
    jmp qword ptr [rax+r12*8]
# label_L
label_4:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 24
    jmp call_undefined_function_handler/3
# label_L
label_5:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 24
    jmp crash/3
# label_L
label_6:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L52
# i_func_label_L
    nop
    align 8
label_7:
# func_line_I
# i_func_info_IaaI
# error_handler:undefined_lambda/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
undefined_lambda/3:
# i_breakpoint_trampoline
    short jmp L53
.db 0x90
    call L41
L53:
# i_test_yield
    lea rdx, qword ptr [undefined_lambda/3+24]
    dec r14d
    long jle L42
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L54
    mov ecx, 3
    call 139636653423200
L54:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call ensure_loaded/1
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_9
    cmp dword ptr [rsi-2], 128
    jne label_9
    cmp qword ptr [rsi+6], 27723
    jne label_9
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+16]
# simplified fetching of BEAM register
    mov rdi, r10
    cmp rdi, rsi
    short je L55
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    je label_9
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_9
L55:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_apply_fun_last_t
    add rsp, 24
    call L56
    mov rdi, 139636653423680
    lea r8, qword ptr [L57]
    test ecx, 1
    short jne L57
    cmp word ptr [rcx-2], dx
    short jne L57
    mov rax, qword ptr [rcx+6]
    mov rdi, qword ptr [rax+r12*8]
L57:
    jmp rdi
# label_L
label_9:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 24
    jmp crash/2
# i_func_label_L
    align 8
label_10:
# func_line_I
# i_func_info_IaaI
# error_handler:breakpoint/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
breakpoint/3:
# i_breakpoint_trampoline
    short jmp L58
.db 0x90
    call L41
L58:
# i_test_yield
    lea rdx, qword ptr [breakpoint/3+24]
    dec r14d
    long jle L42
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L59
    mov ecx, 3
    call 139636653423200
L59:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call int/0
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rbx+24], r11
# i_move_sd
    mov rdx, qword ptr [rsp+8]
    mov qword ptr [rbx+8], rdx
# i_move_sd
    mov qword ptr [rbx+32], 90827
# i_move_sd
    mov rcx, qword ptr [rsp+16]
    mov qword ptr [rbx], rcx
# apply_last_tt
    add rsp, 24
    align 4
L61:
    mov edx, 3
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    lea rcx, qword ptr [L61]
    xor r8d, r8d
    call 94068435489472
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    short jne L60
    lea rsi, qword ptr [L61]
    mov rcx, 94068445024480
    push rsi
    jmp L51
L60:
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_12:
# func_line_I
# i_func_info_IaaI
# error_handler:raise_undef_exception/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x4B, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
raise_undef_exception/3:
# i_breakpoint_trampoline
    short jmp L62
.db 0x90
    call L41
L62:
# i_test_yield
    lea rdx, qword ptr [raise_undef_exception/3+24]
    dec r14d
    long jle L42
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L63
    mov ecx, 3
    call 139636653423200
L63:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 256
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15+8], xmm0
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+24], rdi
    mov qword ptr [r15+32], 59
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 40
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp crash/1
# i_func_label_L
    align 8
label_14:
# func_line_I
# i_func_info_IaaI
# error_handler:int/0
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0xA2, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
int/0:
# i_breakpoint_trampoline
    short jmp L64
.db 0x90
    call L41
L64:
# i_test_yield
    lea rdx, qword ptr [int/0+24]
    dec r14d
    long jle L42
    align 4
# i_move_sd
    mov qword ptr [rbx], 107147
# return
    dec r14d
    jl L65
    ret
# i_func_label_L
    align 8
label_16:
# func_line_I
# i_func_info_IaaI
# error_handler:crash/2
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x49, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
crash/2:
# i_breakpoint_trampoline
    short jmp L66
.db 0x90
    call L41
L66:
# i_test_yield
    lea rdx, qword ptr [crash/2+24]
    dec r14d
    long jle L42
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L67
    mov ecx, 2
    call 139636653423200
L67:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15+8], xmm0
    mov qword ptr [r15+24], 59
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp crash/1
# i_func_label_L
    align 8
label_18:
# func_line_I
# i_func_info_IaaI
# error_handler:crash/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x49, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
crash/3:
# i_breakpoint_trampoline
    short jmp L68
.db 0x90
    call L41
L68:
# i_test_yield
    lea rdx, qword ptr [crash/3+24]
    dec r14d
    long jle L42
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L69
    mov ecx, 3
    call 139636653423200
L69:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 256
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15+8], xmm0
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+24], rdi
    mov qword ptr [r15+32], 59
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 40
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp crash/1
# i_func_label_L
    align 8
label_20:
# func_line_I
# i_func_info_IaaI
# error_handler:crash/1
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x49, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
crash/1:
# i_breakpoint_trampoline
    short jmp L70
.db 0x90
    call L41
L70:
# i_test_yield
    lea rdx, qword ptr [crash/1+24]
    dec r14d
    long jle L42
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L71
    mov ecx, 1
    call 139636653423200
L71:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# catch_yf
    inc qword ptr [r13+256]
L72:
    mov eax, 2147483647
    mov qword ptr [rsp+8], rax
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# call_light_bif_be
    align 4
L73:
L74:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L73]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_22:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_23
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 45899
    jne label_23
# i_move_sd
    mov r10, qword ptr [rbx+16]
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
# line_I
# i_bif1_sjbd
    lea rsi, qword ptr [rbx]
# UBIF: tl/1
    mov rcx, 94068436098576
    call L75
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L76
    mov ecx, 1
    call 139636653423200
L76:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+16], rsi
# i_move_sd
    mov qword ptr [rbx+8], 45899
# i_move_sd
    mov qword ptr [rbx], 779
# line_I
# call_light_bif_be
    align 4
L77:
L78:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091248
    lea rdx, qword ptr [L77]
# BIF: erlang:raise/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L65
    ret
# label_L
label_23:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x90
    call L79
# i_func_label_L
    nop
    align 8
label_24:
# func_line_I
# i_func_info_IaaI
# error_handler:ensure_loaded/1
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x43, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
ensure_loaded/1:
# i_breakpoint_trampoline
    short jmp L80
.db 0x90
    call L41
L80:
# i_test_yield
    lea rdx, qword ptr [ensure_loaded/1+24]
    dec r14d
    long jle L42
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L81
    mov ecx, 1
    call 139636653423200
L81:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# self_d
    mov r11, qword ptr [r13]
    mov qword ptr [rsp], r11
# i_move_sd
    mov qword ptr [rbx], 204107
# line_I
# call_light_bif_be
    align 4
L82:
L83:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094864
    lea rdx, qword ptr [L82]
# BIF: erlang:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
    mov rsi, qword ptr [rsp]
    mov rdi, qword ptr [rbx]
    cmp rdi, rsi
    short je L84
    mov eax, edi
    or eax, esi
    test al, 1
    jne label_26
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_26
L84:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 16
# line_I
# call_light_bif_be
    align 4
L85:
L86:
    long mov rcx, 9223372036854775807
    mov rax, 94068436101616
    lea rdx, qword ptr [L85]
# BIF: erlang:atom_to_list/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
L87:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# call_light_bif_be
    align 4
L88:
L89:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L88]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
L90:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# call_light_bif_be
    align 4
L91:
L92:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L91]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# line_I
# i_call_ext_last_et
L93:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_26:
# is_pid_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L94
    test al, 1
    jne label_27
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_27
L94:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_call_ext_last_et
    add rsp, 16
L95:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_27:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_call_ext_last_et
    add rsp, 16
L96:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_28:
# func_line_I
# i_func_info_IaaI
# error_handler:stub_function/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x4B, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
stub_function/3:
# i_breakpoint_trampoline
    short jmp L97
.db 0x90
    call L41
L97:
# i_test_yield
    lea rdx, qword ptr [stub_function/3+24]
    dec r14d
    long jle L42
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+112]
    cmp rdx, rsp
    short jbe L98
    mov ecx, 3
    call 139636653423200
L98:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 256
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15+8], xmm0
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+24], rdi
    mov qword ptr [r15+32], 59
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 40
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
    mov qword ptr [r15+8], 45899
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L99
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L99:
# call_light_bif_be
    align 4
L100:
L101:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091216
    lea rdx, qword ptr [L100]
# BIF: erlang:exit/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_30:
# func_line_I
# i_func_info_IaaI
# error_handler:call_undefined_function_handler/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x4C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
call_undefined_function_handler/3:
# i_breakpoint_trampoline
    short jmp L102
.db 0x90
    call L41
L102:
# i_test_yield
    lea rdx, qword ptr [call_undefined_function_handler/3+24]
    dec r14d
    long jle L42
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L103
    mov ecx, 3
    call 139636653423200
L103:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# i_move_sd
    mov qword ptr [rbx+16], 47
# i_move_sd
    mov qword ptr [rbx+8], 216139
# line_I
# call_light_bif_be
    align 4
L104:
L105:
    long mov rcx, 9223372036854775807
    mov rax, 94068436111984
    lea rdx, qword ptr [L104]
# BIF: erlang:function_exported/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_33
    cmp rsi, 75
    je label_32
    jmp label_34
# label_L
label_32:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+16]
    mov qword ptr [rbx+16], r11
# i_move_sd
    mov qword ptr [rbx+24], 216139
# i_move_sd
    mov rdx, qword ptr [rsp+8]
    mov qword ptr [rbx], rdx
# line_I
# apply_last_tt
    add rsp, 24
    align 4
L107:
    mov edx, 2
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    lea rcx, qword ptr [L107]
    xor r8d, r8d
    call 94068435489472
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    short jne L106
    lea rsi, qword ptr [L107]
    mov rcx, 94068445024480
    push rsi
    jmp L51
L106:
    jmp qword ptr [rax+r12*8]
# label_L
label_33:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 24
    jmp crash/3
# label_L
label_34:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L52
# i_func_label_L
    nop
    align 8
label_35:
# func_line_I
# i_func_info_IaaI
# error_handler:module_info/0
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L108
.db 0x90
    call L41
L108:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L42
    align 4
# i_move_sd
    mov qword ptr [rbx], 15563
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L109
    mov ecx, 1
.db 0x90
    call 139636653423200
L109:
# call_light_bif_be
    align 4
L110:
L111:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L110]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L65
    ret
# i_func_label_L
    align 8
label_37:
# func_line_I
# i_func_info_IaaI
# error_handler:module_info/1
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L112
.db 0x90
    call L41
L112:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L42
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 15563
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L113
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L113:
# call_light_bif_be
    align 4
L114:
L115:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L114]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L65
    ret
# int_code_end
L116:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L79:
    jmp 139636653427848
L65:
    jmp 139636653422960
L52:
    jmp 139636653427776
L56:
    jmp 139636653420608
L51:
    jmp 139636653427784
L75:
    jmp 139636653424168
L42:
    jmp 139636653426040
L41:
    jmp 139636653424496
L46:
    jmp 139636653425480
L39:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0xCB, 0x24, 0x16, 0x38, 0xAB, 0xE5, 0x0E, 0xA4, 0xE7, 0xB0, 0xF3, 0x61, 0xA1, 0x3D, 0xD5, 0x83, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x2F, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x65, 0x72, 0x72, 0x6F, 0x72, 0x5F, 0x68, 0x61, 0x6E, 0x64, 0x6C, 0x65, 0x72, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0x83, 0xD5, 0x3D, 0xA1, 0x61, 0xF3, 0xB0, 0xE7, 0xA4, 0x0E, 0xE5, 0xAB, 0x38, 0x16, 0x24, 0xCB
.section .text {#0}
