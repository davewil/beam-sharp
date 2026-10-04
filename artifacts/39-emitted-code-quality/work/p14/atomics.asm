    align 8
L38:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# atomics:new/2
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x72, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
new/2:
# i_breakpoint_trampoline
    short jmp L40
.db 0x90
    call L41
L40:
# i_test_yield
    lea rdx, qword ptr [new/2+24]
    dec r14d
    long jle L42
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L43
    mov ecx, 2
    call 139636653423200
L43:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# catch_yf
    inc qword ptr [r13+256]
L44:
    mov eax, 2147483647
    mov qword ptr [rsp+16], rax
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 31
# line_I
# i_call_f
    call label_8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# line_I
# call_light_bif_be
    align 4
L45:
L46:
    long mov rcx, 9223372036854775807
    mov rax, 94068435906752
    lea rdx, qword ptr [L45]
# BIF: erts_internal:atomics_new/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 24
# return
    dec r14d
    jl L47
    ret
# label_L
label_3:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 715
    je label_4
    cmp rsi, 779
    je label_5
    jmp label_6
# label_L
label_4:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 5643
    jne label_6
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L48
    xor ecx, ecx
    call 139636653423200
L48:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# append_cons_Is
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
L49:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# i_move_sd
    mov qword ptr [rbx], 5003
# line_I
# call_light_bif_be
    align 4
L50:
L51:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L50]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_5:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L52
    mov ecx, 2
    call 139636653423200
L52:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# i_move_sd
L53:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L54:
L55:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L54]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_6:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x0F, 0x1F, 0x00
    call L56
# i_func_label_L
    nop
    align 8
label_7:
# func_line_I
# i_func_info_IaaI
# atomics:encode_opts/2
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0xAC, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_8:
# i_breakpoint_trampoline
    short jmp L57
.db 0x90
    call L41
L57:
# i_test_yield
    lea rdx, qword ptr [label_8+24]
    dec r14d
    long jle L42
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_11
    mov rsi, qword ptr [rax-1]
    mov rdx, qword ptr [rax+7]
    mov qword ptr [rbx+16], rsi
    mov qword ptr [rbx], rdx
# i_is_tagged_tuple_fsAa
# skipped fetching of BEAM register
    rex test sil, 1
    jne label_12
    cmp dword ptr [rsi-2], 128
    jne label_12
    cmp qword ptr [rsi+6], 40907
    jne label_12
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+16], r10
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r10
    cmp rsi, 11
    je label_10
    cmp rsi, 75
    je label_9
    jmp label_12
# label_L
label_9:
# i_move_sd
    mov qword ptr [rbx+8], 31
# i_call_only_f
    jmp label_8
# label_L
label_10:
# line_I
# i_band_ssjd
# skipped test for small operands since they are always small
    mov rax, qword ptr [rbx+8]
    and rax, -17
    mov qword ptr [rbx+8], rax
# i_call_only_f
    jmp label_8
# label_L
label_11:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_12
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L47
    ret
# label_L
label_12:
# i_move_sd
    mov qword ptr [rbx], 5643
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L58
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L58:
# call_light_bif_be
    align 4
L59:
L60:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109168
    lea rdx, qword ptr [L59]
# BIF: erlang:throw/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_13:
# func_line_I
# i_func_info_IaaI
# atomics:put/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0xC9, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
put/3:
# i_breakpoint_trampoline
    short jmp L61
.db 0x90
    call L41
L61:
# call_bif_mfa_aaI
# HBIF: atomics:put/3
L62:
    lea rsi, qword ptr [put/3-24]
    lea rdx, qword ptr [L62]
    mov rcx, 94068435907264
    jmp L63
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L64
    mov ecx, 1
    call 139636653423200
L64:
# call_light_bif_be
    align 4
L65:
L66:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L65]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_15:
# func_line_I
# i_func_info_IaaI
# atomics:get/2
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xC1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get/2:
# i_breakpoint_trampoline
    short jmp L67
.db 0x90
    call L41
L67:
# call_bif_mfa_aaI
# HBIF: atomics:get/2
L68:
    lea rsi, qword ptr [get/2-24]
    lea rdx, qword ptr [L68]
    mov rcx, 94068435907504
    jmp L63
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L69
    mov ecx, 1
    call 139636653423200
L69:
# call_light_bif_be
    align 4
L70:
L71:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L70]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_17:
# func_line_I
# i_func_info_IaaI
# atomics:add/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
add/3:
# i_breakpoint_trampoline
    short jmp L72
.db 0x90
    call L41
L72:
# call_bif_mfa_aaI
# HBIF: atomics:add/3
L73:
    lea rsi, qword ptr [add/3-24]
    lea rdx, qword ptr [L73]
    mov rcx, 94068435907968
    jmp L63
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L74
    mov ecx, 1
    call 139636653423200
L74:
# call_light_bif_be
    align 4
L75:
L76:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L75]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_19:
# func_line_I
# i_func_info_IaaI
# atomics:add_get/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
add_get/3:
# i_breakpoint_trampoline
    short jmp L77
.db 0x90
    call L41
L77:
# call_bif_mfa_aaI
# HBIF: atomics:add_get/3
L78:
    lea rsi, qword ptr [add_get/3-24]
    lea rdx, qword ptr [L78]
    mov rcx, 94068435908224
    jmp L63
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L79
    mov ecx, 1
    call 139636653423200
L79:
# call_light_bif_be
    align 4
L80:
L81:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L80]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_21:
# func_line_I
# i_func_info_IaaI
# atomics:sub/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x7D, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
sub/3:
# i_breakpoint_trampoline
    short jmp L82
.db 0x90
    call L41
L82:
# i_test_yield
    lea rdx, qword ptr [sub/3+24]
    dec r14d
    long jle L42
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L83
    mov ecx, 3
    call 139636653423200
L83:
    sub rsp, 32
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# catch_yf
    inc qword ptr [r13+256]
L84:
    mov eax, 2147483647
    mov qword ptr [rsp+24], rax
# line_I
# i_unary_minus_sjd
    mov rsi, qword ptr [rbx+16]
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L86
    movzx rax, al
    mov rdx, rsi
    and rdx, -16
    sub rax, rdx
    short jno L85
L86:
    call L87
L85:
    mov qword ptr [rbx+16], rax
# call_light_bif_be
    align 4
L88:
L89:
    long mov rcx, 9223372036854775807
    mov rax, 94068435907968
    lea rdx, qword ptr [L88]
# BIF: atomics:add/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 32
# return
    dec r14d
    jl L47
    ret
# label_L
label_23:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_24
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L90
    mov ecx, 2
    call 139636653423200
L90:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+32], rdi
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# i_move_sd
L91:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L92:
L93:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L92]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_24:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x0F, 0x1F, 0x00
    call L56
# i_func_label_L
    nop
    align 8
label_25:
# func_line_I
# i_func_info_IaaI
# atomics:sub_get/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x7D, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
sub_get/3:
# i_breakpoint_trampoline
    short jmp L94
.db 0x90
    call L41
L94:
# i_test_yield
    lea rdx, qword ptr [sub_get/3+24]
    dec r14d
    long jle L42
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L95
    mov ecx, 3
    call 139636653423200
L95:
    sub rsp, 32
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# catch_yf
    inc qword ptr [r13+256]
L96:
    mov eax, 2147483647
    mov qword ptr [rsp+24], rax
# line_I
# i_unary_minus_sjd
    mov rsi, qword ptr [rbx+16]
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L98
    movzx rax, al
    mov rdx, rsi
    and rdx, -16
    sub rax, rdx
    short jno L97
L98:
    call L87
L97:
    mov qword ptr [rbx+16], rax
# call_light_bif_be
    align 4
L99:
L100:
    long mov rcx, 9223372036854775807
    mov rax, 94068435908224
    lea rdx, qword ptr [L99]
# BIF: atomics:add_get/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 32
# return
    dec r14d
    jl L47
    ret
# label_L
label_27:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_28
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L101
    mov ecx, 2
    call 139636653423200
L101:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+32], rdi
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# i_move_sd
L102:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L103:
L104:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L103]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_28:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x0F, 0x1F, 0x00
    call L56
# i_func_label_L
    nop
    align 8
label_29:
# func_line_I
# i_func_info_IaaI
# atomics:exchange/3
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
exchange/3:
# i_breakpoint_trampoline
    short jmp L105
.db 0x90
    call L41
L105:
# call_bif_mfa_aaI
# HBIF: atomics:exchange/3
L106:
    lea rsi, qword ptr [exchange/3-24]
    lea rdx, qword ptr [L106]
    mov rcx, 94068435908752
    jmp L63
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L107
    mov ecx, 1
    call 139636653423200
L107:
# call_light_bif_be
    align 4
L108:
L109:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L108]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_31:
# func_line_I
# i_func_info_IaaI
# atomics:compare_exchange/4
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
compare_exchange/4:
# i_breakpoint_trampoline
    short jmp L110
.db 0x90
    call L41
L110:
# call_bif_mfa_aaI
# HBIF: atomics:compare_exchange/4
L111:
    lea rsi, qword ptr [compare_exchange/4-24]
    lea rdx, qword ptr [L111]
    mov rcx, 94068435909264
    jmp L63
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L112
    mov ecx, 1
    call 139636653423200
L112:
# call_light_bif_be
    align 4
L113:
L114:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L113]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_33:
# func_line_I
# i_func_info_IaaI
# atomics:info/1
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x56, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
info/1:
# i_breakpoint_trampoline
    short jmp L115
.db 0x90
    call L41
L115:
# call_bif_mfa_aaI
# HBIF: atomics:info/1
L116:
    lea rsi, qword ptr [info/1-24]
    lea rdx, qword ptr [L116]
    mov rcx, 94068435909856
    jmp L63
# i_move_sd
    mov qword ptr [rbx], 45899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L117
    mov ecx, 1
    call 139636653423200
L117:
# call_light_bif_be
    align 4
L118:
L119:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091024
    lea rdx, qword ptr [L118]
# BIF: erlang:nif_error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_35:
# func_line_I
# i_func_info_IaaI
# atomics:module_info/0
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L120
.db 0x90
    call L41
L120:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L42
    align 4
# i_move_sd
    mov qword ptr [rbx], 69387
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L121
    mov ecx, 1
.db 0x90
    call 139636653423200
L121:
# call_light_bif_be
    align 4
L122:
L123:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L122]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L47
    ret
# i_func_label_L
    align 8
label_37:
# func_line_I
# i_func_info_IaaI
# atomics:module_info/1
    call L39
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L124
.db 0x90
    call L41
L124:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L42
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 69387
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L125
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L125:
# call_light_bif_be
    align 4
L126:
L127:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L126]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L47
    ret
# int_code_end
L128:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L63:
    jmp 139636653421752
L56:
    jmp 139636653427848
L47:
    jmp 139636653422960
L42:
    jmp 139636653426040
L41:
    jmp 139636653424496
L87:
    jmp 139636653427976
L39:
    jmp 139636653424856
.section .rodata {#1}
md5:
.db 0x3E, 0x7B, 0xA1, 0x37, 0x84, 0x87, 0x3F, 0xB4, 0x8A, 0x64, 0xEE, 0x95, 0x20, 0xD2, 0xBF, 0x98
.section .text {#0}
