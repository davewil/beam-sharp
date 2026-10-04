    align 8
L63:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# inet_udp:getserv/1
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0xB1, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
getserv/1:
# i_breakpoint_trampoline
    short jmp L65
.db 0x90
    call L66
L65:
# i_test_yield
    lea rdx, qword ptr [getserv/1+24]
    dec r14d
    long jle L67
    align 4
# is_integer_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 15
    short je L68
    test al, 1
    jne label_3
    mov eax, dword ptr [rdi-2]
    and al, 59
    cmp al, 8
    jne label_3
L68:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L69
    mov ecx, 1
    call 139636653423200
L69:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 32075
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L70
    ret
# label_L
label_3:
# is_atom_fs
    mov rax, qword ptr [rbx]
    and al, 63
    cmp al, 11
    jne label_1
# i_move_sd
    mov qword ptr [rbx+8], 73163
# line_I
# i_call_ext_only_e
L71:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_4:
# func_line_I
# i_func_info_IaaI
# inet_udp:getaddr/1
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xB2, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
getaddr/1:
# i_breakpoint_trampoline
    short jmp L72
.db 0x90
    call L66
L72:
# i_test_yield
    lea rdx, qword ptr [getaddr/1+24]
    dec r14d
    long jle L67
    align 4
# i_move_sd
    mov qword ptr [rbx+8], 72971
# i_call_ext_only_e
L73:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_6:
# func_line_I
# i_func_info_IaaI
# inet_udp:getaddr/2
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xB2, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
getaddr/2:
# i_breakpoint_trampoline
    short jmp L74
.db 0x90
    call L66
L74:
# i_test_yield
    lea rdx, qword ptr [getaddr/2+24]
    dec r14d
    long jle L67
    align 4
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov qword ptr [rbx+8], 72971
# i_call_ext_only_e
L75:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_8:
# func_line_I
# i_func_info_IaaI
# inet_udp:translate_ip/1
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xB2, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
translate_ip/1:
# i_breakpoint_trampoline
    short jmp L76
.db 0x90
    call L66
L76:
# i_test_yield
    lea rdx, qword ptr [translate_ip/1+24]
    dec r14d
    long jle L67
    align 4
# i_move_sd
    mov qword ptr [rbx+8], 72971
# i_call_ext_only_e
L77:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_10:
# func_line_I
# i_func_info_IaaI
# inet_udp:open/1
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x7E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
open/1:
# i_breakpoint_trampoline
    short jmp L78
.db 0x90
    call L66
L78:
# i_test_yield
    lea rdx, qword ptr [open/1+24]
    dec r14d
    long jle L67
    align 4
# i_move_sd
    mov qword ptr [rbx+8], 59
# i_call_only_f
    jmp open/2
# i_func_label_L
    align 8
label_12:
# func_line_I
# i_func_info_IaaI
# inet_udp:open/2
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x7E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
open/2:
# i_breakpoint_trampoline
    short jmp L79
.db 0x90
    call L66
L79:
# i_test_yield
    lea rdx, qword ptr [open/2+24]
    dec r14d
    long jle L67
    align 4
# allocate_heap_tIt
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L80
    mov ecx, 2
    call 139636653423200
L80:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 34315
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_cons_ss
# (put head and tail together)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15], xmm0
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# i_move_sd
    mov qword ptr [rbx+8], 207499
# line_I
# i_call_ext_e
L81:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_25
    cmp dword ptr [rsi-2], 128
    jne label_25
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 779
    je label_24
    cmp rsi, 32075
    je label_14
    jmp label_25
# label_L
label_14:
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx+16]
    rex test sil, 1
    jne label_23
    cmp dword ptr [rsi-2], 320
    jne label_23
    cmp qword ptr [rsi+6], 504459
    jne label_23
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rbx], xmm0
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_15
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_15
# jump_f
    jmp label_22
# label_L
label_15:
# i_band_ssjd
    mov rsi, qword ptr [rbx+8]
    mov rax, -1048561
# is the operand small?
    mov edi, esi
    and edi, 15
    cmp edi, 15
    short jne L82
    and rax, rsi
    short jmp L83
L82:
    call L84
    je label_18
L83:
    mov qword ptr [rbx+24], rax
# bif_is_eq_exact_Ssd
# simplified compare of BEAM register
    cmp rax, 15
    mov eax, 75
    mov edi, 11
    cmovne rax, rdi
    mov qword ptr [rbx+24], rax
# i_is_tuple_of_arity_ff_ffsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_18
    mov eax, dword ptr [rsi-2]
    test al, 63
    jne label_18
    cmp eax, 256
    jne label_16
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+32], xmm0
# i_bor_jssd
    mov rsi, qword ptr [rbx+32]
    mov rax, qword ptr [rbx+40]
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L85
    or rax, rsi
    short jmp L86
L85:
    call L87
    je label_18
L86:
    mov qword ptr [rbx+32], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+40], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L88
    or rax, rsi
    short jmp L89
L88:
    call L87
    je label_18
L89:
    mov qword ptr [rbx+32], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx+40], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L90
    or rax, rsi
    short jmp L91
L90:
    call L87
    je label_18
L91:
    mov qword ptr [rbx+32], rax
# line_I
# i_band_ssjd
# simplified fetching of BEAM register
    mov rsi, rax
    mov rax, -4081
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L92
    and rax, rsi
    short jmp L93
L92:
    call L94
L93:
    mov qword ptr [rbx+32], rax
# bif_is_eq_exact_Ssd
# simplified compare of BEAM register
    cmp rax, 15
    mov eax, 75
    mov edi, 11
    cmovne rax, rdi
    mov qword ptr [rbx+32], rax
# jump_f
    jmp label_17
# label_L
label_16:
# i_move_sd
    mov qword ptr [rbx+32], 11
# label_L
label_17:
# i_bif2_ssjbd
    lea rsi, qword ptr [rbx+24]
# UBIF: and/2
    mov rcx, 94068435875360
    call L95
    mov qword ptr [rbx+24], rax
# jump_f
    jmp label_19
# label_L
label_18:
# i_move_sd
    mov qword ptr [rbx+24], 11
# label_L
label_19:
# i_band_ssjd
    mov rsi, qword ptr [rbx+8]
    mov rax, -1048561
# is the operand small?
    mov edi, esi
    and edi, 15
    cmp edi, 15
    short jne L96
    and rax, rsi
    short jmp L97
L96:
    call L84
    je label_20
L97:
    mov qword ptr [rbx+32], rax
# bif_is_eq_exact_Ssd
# simplified compare of BEAM register
    cmp rax, 15
    mov eax, 75
    mov edi, 11
    cmovne rax, rdi
    mov qword ptr [rbx+32], rax
# bif_is_eq_exact_Ssd
    cmp qword ptr [rbx], 907
    mov eax, 75
    mov edi, 11
    cmovne rax, rdi
    mov qword ptr [rbx+40], rax
# i_bif2_ssjbd
    lea rsi, qword ptr [rbx+32]
# UBIF: and/2
    mov rcx, 94068435875360
    call L95
    mov qword ptr [rbx+32], rax
# jump_f
    jmp label_21
# label_L
label_20:
# i_move_sd
    mov qword ptr [rbx+32], 11
# label_L
label_21:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 11
    jne label_22
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+32], 75
    jne label_23
# label_L
label_22:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+16]
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+30], 1
    vmovups xmmword ptr [rbx+16], xmm0
# i_move_sd
    mov qword ptr [rbx+48], 97739
# i_move_sd
    mov qword ptr [rbx+40], 72971
# i_move_sd
    mov qword ptr [rbx+56], 207499
# i_move_sd
    mov qword ptr [rbx+32], 73163
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx+16], 1
    vmovups xmmword ptr [rbx+16], xmm0
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rbx+8], xmm0
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_last_et
L98:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_23:
# i_move_sd
    mov qword ptr [rbx], 5003
# line_I
# call_light_bif_be
    align 4
L99:
L100:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091216
    lea rdx, qword ptr [L99]
# BIF: erlang:exit/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_24:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L101:
L102:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091216
    lea rdx, qword ptr [L101]
# BIF: erlang:exit/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_25:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L103
# i_func_label_L
    nop
    align 8
label_26:
# func_line_I
# i_func_info_IaaI
# inet_udp:send/4
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x9B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
send/4:
# i_breakpoint_trampoline
    short jmp L104
.db 0x90
    call L66
L104:
# i_test_yield
    lea rdx, qword ptr [send/4+24]
    dec r14d
    long jle L67
    align 4
# i_is_tuple_fs
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    jne label_32
    test byte ptr [rsi-2], 63
    jne label_32
# i_select_tuple_arity_SfI
# skipped fetching of BEAM register
# skipped box test since argument is always boxed
    mov esi, dword ptr [rsi-2]
# simplified tuple test since the source is always a tuple when boxed
    cmp esi, 128
    je label_29
    cmp esi, 256
    je label_28
    short jne label_26
# label_L
label_28:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+32], xmm0
# i_bor_jssd
    mov rsi, qword ptr [rbx+32]
    mov rax, qword ptr [rbx+40]
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L105
    or rax, rsi
    short jmp L106
L105:
    call L87
    je label_26
L106:
    mov qword ptr [rbx+32], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+40], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L107
    or rax, rsi
    short jmp L108
L107:
    call L87
    je label_26
L108:
    mov qword ptr [rbx+32], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx+40], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L109
    or rax, rsi
    short jmp L110
L109:
    call L87
    je label_26
L110:
    mov qword ptr [rbx+32], rax
# line_I
# i_band_ssjd
# simplified fetching of BEAM register
    mov rsi, rax
    mov rax, -4081
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L111
    and rax, rsi
    short jmp L112
L111:
    call L94
L112:
    mov qword ptr [rbx+32], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_26
# i_band_ssjd
    mov rsi, qword ptr [rbx+16]
    mov rax, -1048561
# is the operand small?
    mov edi, esi
    and edi, 15
    cmp edi, 15
    short jne L113
    and rax, rsi
    short jmp L114
L113:
    call L84
    je label_26
L114:
    mov qword ptr [rbx+32], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_26
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L115
    mov ecx, 4
.db 0x66, 0x90
    call 139636653423200
L115:
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
# i_move_sd
    mov qword ptr [rbx+16], 59
# line_I
# i_call_ext_only_e
L116:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_29:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+32], xmm0
# i_is_tuple_of_arity_ff_ffsA
    mov rsi, qword ptr [rbx+32]
    rex test sil, 1
    jne label_30
    mov eax, dword ptr [rsi-2]
    test al, 63
    jne label_30
    cmp eax, 256
    jne label_26
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+48], xmm0
# i_bor_jssd
    mov rsi, qword ptr [rbx+48]
    mov rax, qword ptr [rbx+56]
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L117
    or rax, rsi
    short jmp L118
L117:
    call L87
    je label_26
L118:
    mov qword ptr [rbx+48], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+32]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+56], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L119
    or rax, rsi
    short jmp L120
L119:
    call L87
    je label_26
L120:
    mov qword ptr [rbx+48], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+32]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx+32], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L121
    or rax, rsi
    short jmp L122
L121:
    call L87
    je label_26
L122:
    mov qword ptr [rbx+32], rax
# line_I
# i_band_ssjd
# simplified fetching of BEAM register
    mov rsi, rax
    mov rax, -4081
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L123
    and rax, rsi
    short jmp L124
L123:
    call L94
L124:
    mov qword ptr [rbx+32], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_26
# i_band_ssjd
    mov rsi, qword ptr [rbx+40]
    mov rax, -1048561
# is the operand small?
    mov edi, esi
    and edi, 15
    cmp edi, 15
    short jne L125
    and rax, rsi
    short jmp L126
L125:
    call L84
    je label_26
L126:
    mov qword ptr [rbx+32], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_26
# is_list_fs
    mov rax, qword ptr [rbx+16]
    cmp rax, 59
    short je L127
    test al, 2
    jne label_26
L127:
# line_I
# i_call_ext_only_e
L128:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_30:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+32], 72971
    jne label_26
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+40]
    rex test sil, 1
    jne label_26
    cmp dword ptr [rsi-2], 128
    jne label_26
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+32], xmm0
# i_is_tuple_of_arity_ff_ffsA
    mov rsi, qword ptr [rbx+32]
    rex test sil, 1
    jne label_31
    mov eax, dword ptr [rsi-2]
    test al, 63
    jne label_31
    cmp eax, 256
    jne label_26
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+48], xmm0
# i_bor_jssd
    mov rsi, qword ptr [rbx+48]
    mov rax, qword ptr [rbx+56]
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L129
    or rax, rsi
    short jmp L130
L129:
    call L87
    je label_26
L130:
    mov qword ptr [rbx+48], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+32]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+56], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L131
    or rax, rsi
    short jmp L132
L131:
    call L87
    je label_26
L132:
    mov qword ptr [rbx+48], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+32]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx+32], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L133
    or rax, rsi
    short jmp L134
L133:
    call L87
    je label_26
L134:
    mov qword ptr [rbx+32], rax
# line_I
# i_band_ssjd
# simplified fetching of BEAM register
    mov rsi, rax
    mov rax, -4081
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L135
    and rax, rsi
    short jmp L136
L135:
    call L94
L136:
    mov qword ptr [rbx+32], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_26
# i_band_ssjd
    mov rsi, qword ptr [rbx+40]
    mov rax, -1048561
# is the operand small?
    mov edi, esi
    and edi, 15
    cmp edi, 15
    short jne L137
    and rax, rsi
    short jmp L138
L137:
    call L84
    je label_26
L138:
    mov qword ptr [rbx+32], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_26
# is_list_fs
    mov rax, qword ptr [rbx+16]
    cmp rax, 59
    short je L139
    test al, 2
    jne label_26
L139:
# line_I
# i_call_ext_only_e
L140:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_31:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+32], 108427
    jne label_26
# i_band_ssjd
    mov rsi, qword ptr [rbx+40]
    mov rax, -1048561
# is the operand small?
    mov edi, esi
    and edi, 15
    cmp edi, 15
    short jne L141
    and rax, rsi
    short jmp L142
L141:
    call L84
    je label_26
L142:
    mov qword ptr [rbx+32], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_26
# is_list_fs
    mov rax, qword ptr [rbx+16]
    cmp rax, 59
    short je L143
    test al, 2
    jne label_26
L143:
# line_I
# i_call_ext_only_e
L144:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_32:
# is_map_fs
    mov rdi, qword ptr [rbx+8]
    rex test dil, 1
    jne label_26
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_26
# i_get_map_elements_fsI
.section .rodata {#1}
L147:
    align 8
.db 0x0B, 0x86, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x53, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x00, 0x2B, 0x77, 0x33, 0xBA, 0x32, 0xF1, 0xD8
    align 8
.db 0x0B, 0x81, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x43, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x64, 0x54, 0x61, 0x4F, 0xD7, 0x02, 0xCD, 0x7D
.section .text {#0}
# skipped fetching of BEAM register
# simplified multi-element lookup
    mov eax, dword ptr [rdi-2]
    and al, 252
    cmp al, 44
    jne L145
    mov eax, dword ptr [rdi+6]
    mov rsi, qword ptr [rdi+14]
L148:
    dec eax
    jl label_26
    cmp qword ptr [rsi+rax*8+6], 98571
    short jne L148
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+32], rdx
L149:
    dec eax
    jl label_26
    cmp qword ptr [rsi+rax*8+6], 34315
    short jne L149
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+40], rdx
    short jmp L146
L145:
    mov ecx, 2
    lea r8, qword ptr [L147]
    mov rdx, rsp
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rbx
    call 94068434772192
    mov rsp, rbp
    test rax, rax
    je label_26
L146:
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+32]
    rex test sil, 1
    jne label_26
    cmp dword ptr [rsi-2], 256
    jne label_26
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+48], xmm0
# i_bor_jssd
    mov rsi, qword ptr [rbx+48]
    mov rax, qword ptr [rbx+56]
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L150
    or rax, rsi
    short jmp L151
L150:
    call L87
    je label_26
L151:
    mov qword ptr [rbx+48], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+32]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+56], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L152
    or rax, rsi
    short jmp L153
L152:
    call L87
    je label_26
L153:
    mov qword ptr [rbx+48], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+32]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx+32], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L154
    or rax, rsi
    short jmp L155
L154:
    call L87
    je label_26
L155:
    mov qword ptr [rbx+32], rax
# line_I
# i_band_ssjd
# simplified fetching of BEAM register
    mov rsi, rax
    mov rax, -4081
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L156
    and rax, rsi
    short jmp L157
L156:
    call L94
L157:
    mov qword ptr [rbx+32], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_26
# i_band_ssjd
    mov rsi, qword ptr [rbx+40]
    mov rax, -1048561
# is the operand small?
    mov edi, esi
    and edi, 15
    cmp edi, 15
    short jne L158
    and rax, rsi
    short jmp L159
L158:
    call L84
    je label_26
L159:
    mov qword ptr [rbx+32], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_26
# is_list_fs
    mov rax, qword ptr [rbx+16]
    cmp rax, 59
    short je L160
    test al, 2
    jne label_26
L160:
# line_I
# i_call_ext_only_e
L161:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_33:
# func_line_I
# i_func_info_IaaI
# inet_udp:send/2
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x9B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
send/2:
# i_breakpoint_trampoline
    short jmp L162
.db 0x90
    call L66
L162:
# i_test_yield
    lea rdx, qword ptr [send/2+24]
    dec r14d
    long jle L67
    align 4
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx+24], r10
# i_move_sd
L163:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# line_I
# i_call_ext_only_e
L164:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_35:
# func_line_I
# i_func_info_IaaI
# inet_udp:connect/2
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x27, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
connect/2:
# i_breakpoint_trampoline
    short jmp L165
.db 0x90
    call L66
L165:
# i_test_yield
    lea rdx, qword ptr [connect/2+24]
    dec r14d
    long jle L67
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx+8]
    rex test dil, 1
    short jne label_35
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    short jne label_35
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 108491
    mov rdx, -7215631711770453515
    call L166
    short jne label_35
    mov qword ptr [rbx+16], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 72971
    short jne label_35
# i_move_sd
    mov qword ptr [rbx+16], 395
# line_I
# i_call_ext_only_e
L167:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_37:
# func_line_I
# i_func_info_IaaI
# inet_udp:connect/3
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x27, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
connect/3:
# i_breakpoint_trampoline
    short jmp L168
.db 0x90
    call L66
L168:
# i_test_yield
    lea rdx, qword ptr [connect/3+24]
    dec r14d
    long jle L67
    align 4
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    short jne label_37
    cmp dword ptr [rsi-2], 256
    short jne label_37
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+24], xmm0
# i_bor_jssd
    mov rsi, qword ptr [rbx+24]
    mov rax, qword ptr [rbx+32]
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L169
    or rax, rsi
    short jmp L170
L169:
    call L87
    short je label_37
L170:
    mov qword ptr [rbx+24], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+32], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L171
    or rax, rsi
    short jmp L172
L171:
    call L87
    je label_37
L172:
    mov qword ptr [rbx+24], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx+32], r10
# i_bor_jssd
# simplified fetching of BEAM register
    mov rsi, rax
# simplified fetching of BEAM register
    mov rax, r10
# are both operands small?
    mov edi, esi
    and edi, eax
    and edi, 15
    cmp edi, 15
    short jne L173
    or rax, rsi
    short jmp L174
L173:
    call L87
    je label_37
L174:
    mov qword ptr [rbx+24], rax
# line_I
# i_band_ssjd
# simplified fetching of BEAM register
    mov rsi, rax
    mov rax, -4081
# simplified test for small operands since both are numbers
    rex test sil, 1
    short je L175
    and rax, rsi
    short jmp L176
L175:
    call L94
L176:
    mov qword ptr [rbx+24], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_37
# i_band_ssjd
    mov rsi, qword ptr [rbx+16]
    mov rax, -1048561
# is the operand small?
    mov edi, esi
    and edi, 15
    cmp edi, 15
    short jne L177
    and rax, rsi
    short jmp L178
L177:
    call L84
    je label_37
L178:
    mov qword ptr [rbx+24], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_37
# line_I
# i_call_ext_only_e
L179:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_39:
# func_line_I
# i_func_info_IaaI
# inet_udp:recv/2
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x87, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
recv/2:
# i_breakpoint_trampoline
    short jmp L180
.db 0x90
    call L66
L180:
# line_I
# i_test_yield
    lea rdx, qword ptr [recv/2+24]
    dec r14d
    long jle L67
    align 4
# i_call_ext_only_e
L181:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_41:
# func_line_I
# i_func_info_IaaI
# inet_udp:recv/3
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x87, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
recv/3:
# i_breakpoint_trampoline
    short jmp L182
.db 0x90
    call L66
L182:
# line_I
# i_test_yield
    lea rdx, qword ptr [recv/3+24]
    dec r14d
    long jle L67
    align 4
# i_call_ext_only_e
L183:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_43:
# func_line_I
# i_func_info_IaaI
# inet_udp:close/1
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
close/1:
# i_breakpoint_trampoline
    short jmp L184
.db 0x90
    call L66
L184:
# line_I
# i_test_yield
    lea rdx, qword ptr [close/1+24]
    dec r14d
    long jle L67
    align 4
# i_call_ext_only_e
L185:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_45:
# func_line_I
# i_func_info_IaaI
# inet_udp:controlling_process/2
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x0F, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
controlling_process/2:
# i_breakpoint_trampoline
    short jmp L186
.db 0x90
    call L66
L186:
# line_I
# i_test_yield
    lea rdx, qword ptr [controlling_process/2+24]
    dec r14d
    long jle L67
    align 4
# i_call_ext_only_e
L187:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_47:
# func_line_I
# i_func_info_IaaI
# inet_udp:fdopen/2
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x7C, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
fdopen/2:
# i_breakpoint_trampoline
    short jmp L188
.db 0x90
    call L66
L188:
# i_test_yield
    lea rdx, qword ptr [fdopen/2+24]
    dec r14d
    long jle L67
    align 4
# allocate_heap_tIt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L189
    mov ecx, 2
    call 139636653423200
L189:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# put_cons_ss
L190:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# line_I
# i_call_f
    call optuniquify/1
# i_move_sd
    mov qword ptr [rbx+24], 72971
# i_move_sd
    mov qword ptr [rbx+16], 73163
# i_move_sd
    mov qword ptr [rbx+32], 97739
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+40], 207499
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_ext_last_et
    add rsp, 8
L191:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_49:
# func_line_I
# i_func_info_IaaI
# inet_udp:optuniquify/1
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0xB3, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
optuniquify/1:
# i_breakpoint_trampoline
    short jmp L192
.db 0x90
    call L66
L192:
# i_test_yield
    lea rdx, qword ptr [optuniquify/1+24]
    dec r14d
    long jle L67
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L193
    mov ecx, 1
    call 139636653423200
L193:
# line_I
# i_call_ext_e
L194:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx+8], 59
# i_call_last_ft
    jmp optuniquify/2
# i_func_label_L
    align 8
label_51:
# func_line_I
# i_func_info_IaaI
# inet_udp:optuniquify/2
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0xB3, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
optuniquify/2:
# i_breakpoint_trampoline
    short jmp L195
.db 0x90
    call L66
L195:
# i_test_yield
    lea rdx, qword ptr [optuniquify/2+24]
    dec r14d
    long jle L67
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_53
    mov rsi, qword ptr [rax-1]
    mov rdx, qword ptr [rax+7]
    mov qword ptr [rbx+16], rsi
    mov qword ptr [rbx], rdx
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx+24], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx+8], rdx
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], rsi
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_call_only_f
    jmp optuniquify/4
# label_L
label_53:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L70
    ret
# i_func_label_L
    align 8
label_54:
# func_line_I
# i_func_info_IaaI
# inet_udp:optuniquify/4
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0xB3, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
optuniquify/4:
# i_breakpoint_trampoline
    short jmp L196
.db 0x90
    call L66
L196:
# i_test_yield
    lea rdx, qword ptr [optuniquify/4+24]
    dec r14d
    long jle L67
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx+8]
    test al, 2
    jne label_59
    mov rsi, qword ptr [rax-1]
    mov rdx, qword ptr [rax+7]
    mov qword ptr [rbx+32], rsi
    mov qword ptr [rbx+8], rdx
# bif_tuple_size_bjSd
    lea rsi, qword ptr [rbx]
# UBIF: tuple_size/1
    mov rcx, 94068436098688
    call L197
    je label_56
    mov qword ptr [rbx+40], rax
# bif_tuple_size_bjSd
    lea rsi, qword ptr [rbx+32]
# UBIF: tuple_size/1
    mov rcx, 94068436098688
    call L197
    je label_56
    mov qword ptr [rbx+48], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified fetching of BEAM register
    mov rdi, rax
    cmp qword ptr [rbx+40], rdi
    jne label_56
# bif_element_jssd
    mov rsi, qword ptr [rbx]
# skipped tuple test since source is always a tuple
    cmp dword ptr [rsi-2], 64
    jb label_56
    mov rax, qword ptr [rsi+6]
    mov qword ptr [rbx+40], rax
# bif_element_jssd
    mov rsi, qword ptr [rbx+32]
# skipped tuple test since source is always a tuple
    cmp dword ptr [rsi-2], 64
    jb label_56
    mov rax, qword ptr [rsi+6]
    mov qword ptr [rbx+48], rax
# is_ne_exact_fss
# simplified fetching of BEAM register
    mov rsi, rax
    mov rdi, qword ptr [rbx+40]
    cmp rdi, rsi
    je label_57
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    short je L198
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    jnz label_57
L198:
# label_L
label_56:
# is_eq_exact_fss
    mov rsi, qword ptr [rbx]
    mov rdi, qword ptr [rbx+32]
    cmp rdi, rsi
    short je L199
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    je label_58
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_58
L199:
# label_L
label_57:
# i_call_only_f
    jmp optuniquify/4
# label_L
label_58:
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L200
    mov ecx, 5
    call 139636653423200
L200:
# put_cons_ss
    mov rdi, qword ptr [rbx+32]
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+16], rsi
# i_call_only_f
    jmp optuniquify/4
# label_L
label_59:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L201
    mov ecx, 4
    call 139636653423200
L201:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+8], r11
# i_move_sd
    mov rdx, qword ptr [rbx+16]
    mov qword ptr [rbx], rdx
# line_I
# i_call_ext_e
L202:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L203
    mov ecx, 1
    call 139636653423200
L203:
# put_cons_ss
# (putting and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [r15], xmm0
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_call_last_ft
    add rsp, 16
    jmp optuniquify/2
# i_func_label_L
    align 8
label_60:
# func_line_I
# i_func_info_IaaI
# inet_udp:module_info/0
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L204
.db 0x90
    call L66
L204:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L67
    align 4
# i_move_sd
    mov qword ptr [rbx], 207499
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L205
    mov ecx, 1
.db 0x90
    call 139636653423200
L205:
# call_light_bif_be
    align 4
L206:
L207:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L206]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L70
    ret
# i_func_label_L
    align 8
label_62:
# func_line_I
# i_func_info_IaaI
# inet_udp:module_info/1
    call L64
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L208
.db 0x90
    call L66
L208:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L67
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 207499
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L209
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L209:
# call_light_bif_be
    align 4
L210:
L211:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L210]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L70
    ret
# int_code_end
L212:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L197:
    jmp 139636653424264
L87:
    jmp 139636653424368
L103:
    jmp 139636653427776
L84:
    jmp 139636653424136
L166:
    jmp 139636653425144
L70:
    jmp 139636653422960
L95:
    jmp 139636653424168
L94:
    jmp 139636653424064
L67:
    jmp 139636653426040
L66:
    jmp 139636653424496
L64:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0x0C, 0xFB, 0xA4, 0x3C, 0x6D, 0xD6, 0x9A, 0x95, 0x3E, 0xAF, 0xEE, 0xA0, 0xF6, 0xBF, 0x24, 0x77, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x2A, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x69, 0x6E, 0x65, 0x74, 0x5F, 0x75, 0x64, 0x70, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0x77, 0x24, 0xBF, 0xF6, 0xA0, 0xEE, 0xAF, 0x3E, 0x95, 0x9A, 0xD6, 0x6D, 0x3C, 0xA4, 0xFB, 0x0C
.section .text {#0}
