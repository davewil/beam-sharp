    align 8
L54:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# counters:new/2
    call L55
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x72, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
new/2:
# i_breakpoint_trampoline
    short jmp L56
.db 0x90
    call L57
L56:
# i_test_yield
    lea rdx, qword ptr [new/2+24]
    dec r14d
    long jle L58
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L59
    mov ecx, 2
    call 139636653423200
L59:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# catch_yf
    inc qword ptr [r13+256]
L60:
    mov eax, 2147483647
    mov qword ptr [rsp+16], rax
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx+8]
    test al, 2
    jne label_5
# (moving head and tail together)
    vmovups xmm0, xmmword ptr [rax-1]
    vmovups xmmword ptr [rbx], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 47755
    je label_3
    cmp rsi, 69387
    je label_4
    jmp label_7
# label_L
label_3:
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    jne label_7
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L61:
L62:
    long mov rcx, 9223372036854775807
    mov rax, 94068435910432
    lea rdx, qword ptr [L61]
# BIF: erts_internal:counters_new/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L63
    mov ecx, 1
    call 139636653423200
L63:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 47755
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# jump_f
    jmp label_6
# label_L
label_4:
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    jne label_7
# i_move_sd
L64:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L65:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L66
    mov ecx, 1
    call 139636653423200
L66:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 69387
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# jump_f
    jmp label_6
# label_L
label_5:
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    jne label_7
# i_move_sd
L67:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# line_I
# i_call_ext_e
L68:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
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
    mov qword ptr [r15+8], 69387
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# label_L
label_6:
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 24
# return
    dec r14d
    jl L70
    ret
# label_L
label_7:
# i_move_sd
    mov qword ptr [rbx], 5643
# line_I
# call_light_bif_be
    align 4
L71:
L72:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L71]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_8:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_10
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 5643
    jne label_9
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L73
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L73:
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
L74:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# i_move_sd
    mov qword ptr [rbx], 5003
# line_I
# call_light_bif_be
    align 4
L75:
L76:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L75]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_9:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L77
    mov ecx, 2
    call 139636653423200
L77:
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
L78:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L79:
L80:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L79]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_10:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x0F, 0x1F, 0x00
    call L81
# i_func_label_L
    nop
    align 8
label_11:
# func_line_I
# i_func_info_IaaI
# counters:get/2
    call L55
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xC1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get/2:
# i_breakpoint_trampoline
    short jmp L82
.db 0x90
    call L57
L82:
# i_test_yield
    lea rdx, qword ptr [get/2+24]
    dec r14d
    long jle L58
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L83
    mov ecx, 2
    call 139636653423200
L83:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# catch_yf
    inc qword ptr [r13+256]
L84:
    mov eax, 2147483647
    mov qword ptr [rsp+16], rax
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_16
    cmp dword ptr [rsi-2], 128
    jne label_16
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+8]
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r11
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r10
    cmp rsi, 47755
    je label_13
    cmp rsi, 69387
    je label_14
    jmp label_16
# label_L
label_13:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx+8], r11
# line_I
# call_light_bif_be
    align 4
L85:
L86:
    long mov rcx, 9223372036854775807
    mov rax, 94068435911024
    lea rdx, qword ptr [L85]
# BIF: erts_internal:counters_get/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# jump_f
    jmp label_15
# label_L
label_14:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx+8], r11
# line_I
# call_light_bif_be
    align 4
L87:
L88:
    long mov rcx, 9223372036854775807
    mov rax, 94068435907504
    lea rdx, qword ptr [L87]
# BIF: atomics:get/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_15:
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 24
# return
    dec r14d
    jl L70
    ret
# label_L
label_16:
# i_move_sd
    mov qword ptr [rbx], 5003
# line_I
# call_light_bif_be
    align 4
L89:
L90:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L89]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_17:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_18
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L91
    mov ecx, 2
.db 0x90
    call 139636653423200
L91:
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
L92:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L93:
L94:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L93]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_18:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x0F, 0x1F, 0x00
    call L81
# i_func_label_L
    nop
    align 8
label_19:
# func_line_I
# i_func_info_IaaI
# counters:add/3
    call L55
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
add/3:
# i_breakpoint_trampoline
    short jmp L95
.db 0x90
    call L57
L95:
# i_test_yield
    lea rdx, qword ptr [add/3+24]
    dec r14d
    long jle L58
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L96
    mov ecx, 3
    call 139636653423200
L96:
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
L97:
    mov eax, 2147483647
    mov qword ptr [rsp+24], rax
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_24
    cmp dword ptr [rsi-2], 128
    jne label_24
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+16]
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r11
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r10
    cmp rsi, 47755
    je label_21
    cmp rsi, 69387
    je label_22
    jmp label_24
# label_L
label_21:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r11
# line_I
# call_light_bif_be
    align 4
L98:
L99:
    long mov rcx, 9223372036854775807
    mov rax, 94068435911408
    lea rdx, qword ptr [L98]
# BIF: erts_internal:counters_add/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# jump_f
    jmp label_23
# label_L
label_22:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r11
# line_I
# call_light_bif_be
    align 4
L100:
L101:
    long mov rcx, 9223372036854775807
    mov rax, 94068435907968
    lea rdx, qword ptr [L100]
# BIF: atomics:add/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_23:
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 32
# return
    dec r14d
    jl L70
    ret
# label_L
label_24:
# i_move_sd
    mov qword ptr [rbx], 5003
# line_I
# call_light_bif_be
    align 4
L102:
L103:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L102]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_25:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_26
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L104
    mov ecx, 2
.db 0x90
    call 139636653423200
L104:
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
L105:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L106:
L107:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L106]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_26:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x0F, 0x1F, 0x00
    call L81
# i_func_label_L
    nop
    align 8
label_27:
# func_line_I
# i_func_info_IaaI
# counters:sub/3
    call L55
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x7D, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
sub/3:
# i_breakpoint_trampoline
    short jmp L108
.db 0x90
    call L57
L108:
# i_test_yield
    lea rdx, qword ptr [sub/3+24]
    dec r14d
    long jle L58
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L109
    mov ecx, 3
    call 139636653423200
L109:
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
L110:
    mov eax, 2147483647
    mov qword ptr [rsp+24], rax
# line_I
# i_unary_minus_sjd
    mov rsi, qword ptr [rbx+16]
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L112
    movzx rax, al
    mov rdx, rsi
    and rdx, -16
    sub rax, rdx
    short jno L111
L112:
    call L113
L111:
    mov qword ptr [rbx], rax
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rsp+16]
    rex test sil, 1
    jne label_32
    cmp dword ptr [rsi-2], 128
    jne label_32
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 47755
    je label_29
    cmp rsi, 69387
    je label_30
    jmp label_32
# label_L
label_29:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# swap_dd
    mov rdi, qword ptr [rbx]
    mov rsi, qword ptr [rbx+16]
    mov qword ptr [rbx+16], rdi
    mov qword ptr [rbx], rsi
# line_I
# call_light_bif_be
    align 4
L114:
L115:
    long mov rcx, 9223372036854775807
    mov rax, 94068435911408
    lea rdx, qword ptr [L114]
# BIF: erts_internal:counters_add/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# jump_f
    jmp label_31
# label_L
label_30:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# swap_dd
    mov rdi, qword ptr [rbx]
    mov rsi, qword ptr [rbx+16]
    mov qword ptr [rbx+16], rdi
    mov qword ptr [rbx], rsi
# line_I
# call_light_bif_be
    align 4
L116:
L117:
    long mov rcx, 9223372036854775807
    mov rax, 94068435907968
    lea rdx, qword ptr [L116]
# BIF: atomics:add/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_31:
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 32
# return
    dec r14d
    jl L70
    ret
# label_L
label_32:
# i_move_sd
    mov qword ptr [rbx], 5003
# line_I
# call_light_bif_be
    align 4
L118:
L119:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L118]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_33:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_34
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L120
    mov ecx, 2
.db 0x90
    call 139636653423200
L120:
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
L121:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L122:
L123:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L122]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_34:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x0F, 0x1F, 0x00
    call L81
# i_func_label_L
    nop
    align 8
label_35:
# func_line_I
# i_func_info_IaaI
# counters:put/3
    call L55
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0xC9, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
put/3:
# i_breakpoint_trampoline
    short jmp L124
.db 0x90
    call L57
L124:
# i_test_yield
    lea rdx, qword ptr [put/3+24]
    dec r14d
    long jle L58
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L125
    mov ecx, 3
    call 139636653423200
L125:
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
L126:
    mov eax, 2147483647
    mov qword ptr [rsp+24], rax
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_40
    cmp dword ptr [rsi-2], 128
    jne label_40
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+16]
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r11
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r10
    cmp rsi, 47755
    je label_37
    cmp rsi, 69387
    je label_38
    jmp label_40
# label_L
label_37:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r11
# line_I
# call_light_bif_be
    align 4
L127:
L128:
    long mov rcx, 9223372036854775807
    mov rax, 94068435911728
    lea rdx, qword ptr [L127]
# BIF: erts_internal:counters_put/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# jump_f
    jmp label_39
# label_L
label_38:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r11
# line_I
# call_light_bif_be
    align 4
L129:
L130:
    long mov rcx, 9223372036854775807
    mov rax, 94068435907264
    lea rdx, qword ptr [L129]
# BIF: atomics:put/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_39:
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 32
# return
    dec r14d
    jl L70
    ret
# label_L
label_40:
# i_move_sd
    mov qword ptr [rbx], 5003
# line_I
# call_light_bif_be
    align 4
L131:
L132:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L131]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_41:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_42
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L133
    mov ecx, 2
.db 0x90
    call 139636653423200
L133:
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
L134:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L135:
L136:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L135]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_42:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x0F, 0x1F, 0x00
    call L81
# i_func_label_L
    nop
    align 8
label_43:
# func_line_I
# i_func_info_IaaI
# counters:info/1
    call L55
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x56, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
info/1:
# i_breakpoint_trampoline
    short jmp L137
.db 0x90
    call L57
L137:
# i_test_yield
    lea rdx, qword ptr [info/1+24]
    dec r14d
    long jle L58
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L138
    mov ecx, 1
    call 139636653423200
L138:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# catch_yf
    inc qword ptr [r13+256]
L139:
    mov eax, 2147483647
    mov qword ptr [rsp+8], rax
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_48
    cmp dword ptr [rsi-2], 128
    jne label_48
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp]
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r11
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r10
    cmp rsi, 47755
    je label_45
    cmp rsi, 69387
    je label_46
    jmp label_48
# label_L
label_45:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L140:
L141:
    long mov rcx, 9223372036854775807
    mov rax, 94068435912032
    lea rdx, qword ptr [L140]
# BIF: erts_internal:counters_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# jump_f
    jmp label_47
# label_L
label_46:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L142:
L143:
    long mov rcx, 9223372036854775807
    mov rax, 94068435909856
    lea rdx, qword ptr [L142]
# BIF: atomics:info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_47:
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 16
# return
    dec r14d
    jl L70
    ret
# label_L
label_48:
# i_move_sd
    mov qword ptr [rbx], 5003
# line_I
# call_light_bif_be
    align 4
L144:
L145:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L144]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_49:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_50
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L146
    mov ecx, 2
.db 0x90
    call 139636653423200
L146:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# i_move_sd
L147:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L148:
L149:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090624
    lea rdx, qword ptr [L148]
# BIF: erlang:error/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_50:
# raise_ss
    mov rdx, qword ptr [rbx+8]
    mov rsi, qword ptr [rbx+16]
.db 0x0F, 0x1F, 0x00
    call L81
# i_func_label_L
    nop
    align 8
label_51:
# func_line_I
# i_func_info_IaaI
# counters:module_info/0
    call L55
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L150
.db 0x90
    call L57
L150:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L58
    align 4
# i_move_sd
    mov qword ptr [rbx], 10763
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L151
    mov ecx, 1
.db 0x90
    call 139636653423200
L151:
# call_light_bif_be
    align 4
L152:
L153:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L152]
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
label_53:
# func_line_I
# i_func_info_IaaI
# counters:module_info/1
    call L55
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L154
.db 0x90
    call L57
L154:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L58
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 10763
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L155
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L155:
# call_light_bif_be
    align 4
L156:
L157:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L156]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L70
    ret
# int_code_end
L158:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L81:
    jmp 139636653427848
L70:
    jmp 139636653422960
L58:
    jmp 139636653426040
L57:
    jmp 139636653424496
L113:
    jmp 139636653427976
L55:
    jmp 139636653424856
.section .rodata {#1}
md5:
.db 0x4B, 0x2F, 0x5B, 0x48, 0xBB, 0xF5, 0x73, 0xE2, 0x4F, 0xC6, 0xF5, 0xF8, 0xF1, 0xC5, 0xD7, 0x46
.section .text {#0}
