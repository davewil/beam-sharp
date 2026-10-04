    align 8
L50:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# kernel_refc:start_link/0
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x42, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_link/0:
# i_breakpoint_trampoline
    short jmp L52
.db 0x90
    call L53
L52:
# i_test_yield
    lea rdx, qword ptr [start_link/0+24]
    dec r14d
    long jle L54
    align 4
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov qword ptr [rbx+8], 160331
# i_move_sd
    mov qword ptr [rbx+24], 59
# i_move_sd
L55:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_call_ext_only_e
L56:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_3:
# func_line_I
# i_func_info_IaaI
# kernel_refc:scheduler_wall_time/1
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x99, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
scheduler_wall_time/1:
# i_breakpoint_trampoline
    short jmp L57
.db 0x90
    call L53
L57:
# i_test_yield
    lea rdx, qword ptr [scheduler_wall_time/1+24]
    dec r14d
    long jle L54
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L58
    mov ecx, 1
    call 139636653423200
L58:
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx+8], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 39179
# (moving and swapping two elements at once)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov qword ptr [rbx+16], 395
# i_move_sd
    mov qword ptr [rbx], 160331
# i_call_ext_only_e
L59:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_5:
# func_line_I
# i_func_info_IaaI
# kernel_refc:init/1
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
init/1:
# i_breakpoint_trampoline
    short jmp L60
.db 0x90
    call L53
L60:
# i_test_yield
    lea rdx, qword ptr [init/1+24]
    dec r14d
    long jle L54
    align 4
# is_nil_fS
    cmp byte ptr [rbx], 59
    short jne label_5
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L61
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L61:
# i_move_sd
    mov qword ptr [rbx+8], 11
# i_move_sd
    mov qword ptr [rbx], 39179
# line_I
# i_call_f
    call resource/2
# i_move_sd
L62:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_7:
# func_line_I
# i_func_info_IaaI
# kernel_refc:handle_call/3
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x59, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_call/3:
# i_breakpoint_trampoline
    short jmp L64
.db 0x90
    call L53
L64:
# i_test_yield
    lea rdx, qword ptr [handle_call/3+24]
    dec r14d
    long jle L54
    align 4
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_11
    cmp dword ptr [rsi-2], 192
    jne label_11
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+24], r11
# i_get_tuple_element_sPS
    mov rdx, qword ptr [rsi+22]
    mov qword ptr [rbx], rdx
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, rdx
    cmp rsi, 11
    je label_10
    cmp rsi, 75
    je label_9
    jmp label_11
# label_L
label_9:
# line_I
# bif_map_get_jssd
    mov rdi, qword ptr [rbx+16]
    mov rsi, qword ptr [rbx+8]
    rex test dil, 1
    jne L66
    mov rax, qword ptr [rdi-2]
    and al, 63
    cmp al, 44
    short je L67
L66:
.db 0x90
    call 139636653423960
L67:
    call L68
    je L65
    mov rdi, qword ptr [rbx+16]
    mov rsi, qword ptr [rbx+8]
.db 0x0F, 0x1F, 0x00
    call 139636653423920
L65:
    mov qword ptr [rbx], rax
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L69
    mov ecx, 4
.db 0x90
    call 139636653423200
L69:
    sub rsp, 16
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+8]
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx+16], r10
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_f
.db 0x0F, 0x1F, 0x00
    call do_start/3
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# line_I
# update_map_exact_sjdtI
    mov rsi, qword ptr [rsp]
# simplified fetching of BEAM register
    mov rdx, r10
    mov rcx, qword ptr [rsp+8]
.db 0x0F, 0x1F, 0x00
    call 139636653428392
    mov qword ptr [rbx+8], rax
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L70
    mov ecx, 2
    call 139636653423200
L70:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r11
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L63
    ret
# label_L
label_10:
# line_I
# bif_map_get_jssd
    mov rdi, qword ptr [rbx+16]
    mov rsi, qword ptr [rbx+8]
    rex test dil, 1
    jne L72
    mov rax, qword ptr [rdi-2]
    and al, 63
    cmp al, 44
    short je L73
L72:
.db 0x66, 0x90
    call 139636653423960
L73:
    call L68
    je L71
    mov rdi, qword ptr [rbx+16]
    mov rsi, qword ptr [rbx+8]
.db 0x0F, 0x1F, 0x00
    call 139636653423920
L71:
    mov qword ptr [rbx], rax
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L74
    mov ecx, 4
.db 0x90
    call 139636653423200
L74:
    sub rsp, 16
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+8]
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx+16], r10
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_f
.db 0x0F, 0x1F, 0x00
    call do_stop/3
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# line_I
# update_map_exact_sjdtI
    mov rsi, qword ptr [rsp]
# simplified fetching of BEAM register
    mov rdx, r10
    mov rcx, qword ptr [rsp+8]
.db 0x0F, 0x1F, 0x00
    call 139636653428392
    mov qword ptr [rbx+8], rax
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L75
    mov ecx, 2
    call 139636653423200
L75:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r11
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L63
    ret
# label_L
label_11:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L76
    mov ecx, 3
    call 139636653423200
L76:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov qword ptr [r15+16], 5003
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_12:
# func_line_I
# i_func_info_IaaI
# kernel_refc:handle_cast/2
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x5C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_cast/2:
# i_breakpoint_trampoline
    short jmp L77
.db 0x90
    call L53
L77:
# i_test_yield
    lea rdx, qword ptr [handle_cast/2+24]
    dec r14d
    long jle L54
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L78
    mov ecx, 2
    call 139636653423200
L78:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 219531
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_14:
# func_line_I
# i_func_info_IaaI
# kernel_refc:handle_info/2
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x5D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_info/2:
# i_breakpoint_trampoline
    short jmp L79
.db 0x90
    call L53
L79:
# i_test_yield
    lea rdx, qword ptr [handle_info/2+24]
    dec r14d
    long jle L54
    align 4
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_16
    cmp dword ptr [rsi-2], 320
    jne label_16
    cmp qword ptr [rsi+6], 1355
    jne label_16
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+16], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 35211
    jne label_16
# allocate_heap_tIt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L80
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L80:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx], r10
# i_make_fun3_FStt
L81:
    long mov rax, 9223372036854775807
# Create fun thing
    mov qword ptr [r15], 66068
    mov qword ptr [r15+8], rax
# Move fun environment
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea rax, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], rax
# line_I
# i_call_ext_e
L82:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L83
    mov ecx, 1
    call 139636653423200
L83:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 219531
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
# return
    dec r14d
    jl L63
    ret
# label_L
label_16:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L84
    mov ecx, 2
.db 0x90
    call 139636653423200
L84:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 219531
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_17:
# func_line_I
# i_func_info_IaaI
# kernel_refc:terminate/2
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x53, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
terminate/2:
# i_breakpoint_trampoline
    short jmp L85
.db 0x90
    call L53
L85:
# i_test_yield
    lea rdx, qword ptr [terminate/2+24]
    dec r14d
    long jle L54
    align 4
# i_move_sd
    mov qword ptr [rbx], 32075
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_19:
# func_line_I
# i_func_info_IaaI
# kernel_refc:code_change/3
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x61, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
code_change/3:
# i_breakpoint_trampoline
    short jmp L86
.db 0x90
    call L53
L86:
# i_test_yield
    lea rdx, qword ptr [code_change/3+24]
    dec r14d
    long jle L54
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L87
    mov ecx, 2
    call 139636653423200
L87:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 32075
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_21:
# func_line_I
# i_func_info_IaaI
# kernel_refc:do_start/3
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x63, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_start/3:
# i_breakpoint_trampoline
    short jmp L88
.db 0x90
    call L53
L88:
# i_test_yield
    lea rdx, qword ptr [do_start/3+24]
    dec r14d
    long jle L54
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx+8]
    rex test dil, 1
    jne label_26
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_26
# i_get_map_element_fSSS
# skipped fetching of BEAM register
    mov rsi, qword ptr [rbx+16]
    call L68
    jne label_24
    mov qword ptr [rbx+24], rax
# i_is_tuple_of_arity_ff_ffsA
# simplified fetching of BEAM register
    mov rsi, rax
    rex test sil, 1
    jne label_23
    mov eax, dword ptr [rsi-2]
    test al, 63
    jne label_23
    cmp eax, 128
    jne label_27
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# line_I
# i_plus_ssjd
# simplified fetching of BEAM register
    mov rsi, r10
    mov edx, 31
# is the operand small?
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L90
    lea rax, qword ptr [rsi-15]
    add rax, rdx
    short jno L89
L90:
    call L91
L89:
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L92
    mov ecx, 4
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L92:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+24]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+24], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# update_map_assoc_sdtI
    mov rsi, qword ptr [rbx+16]
# simplified fetching of BEAM register
    mov rdx, r11
    mov rcx, qword ptr [rbx+8]
    call L93
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L94
    mov ecx, 1
.db 0x90
    call 139636653423200
L94:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 75
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L63
    ret
# label_L
label_23:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 907
    jne label_27
# label_L
label_24:
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L95
    mov ecx, 3
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L95:
    sub rsp, 32
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+24], r10
# i_move_sd
    mov r11, qword ptr [rbx+16]
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov qword ptr [rbx], 35211
# line_I
# call_light_bif_be
    align 4
L96:
L97:
    long mov rcx, 9223372036854775807
    mov rax, 94068436086224
    lea rdx, qword ptr [L96]
# BIF: erlang:monitor/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rsp+16]
    mov qword ptr [rbx], r11
# line_I
# i_call_f
    call any/1
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_25
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L98
    xor ecx, ecx
.db 0x90
    call 139636653423200
L98:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 31
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# update_map_assoc_sdtI
    mov rsi, qword ptr [rsp+8]
# simplified fetching of BEAM register
    mov rdx, r10
    mov rcx, qword ptr [rsp+16]
    call L93
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L99
    mov ecx, 1
.db 0x90
    call 139636653423200
L99:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 75
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 32
# return
    dec r14d
    jl L63
    ret
# label_L
label_25:
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov r10, qword ptr [rsp+24]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rsp+24], r11
# i_trim_t
    add rsp, 8
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call resource/2
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L100
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L100:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 31
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# update_map_assoc_sdtI
    mov rsi, qword ptr [rsp]
# simplified fetching of BEAM register
    mov rdx, r10
    mov rcx, qword ptr [rsp+8]
    call L93
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L101
    mov ecx, 1
.db 0x90
    call 139636653423200
L101:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 11
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 24
# return
    dec r14d
    jl L63
    ret
# label_L
label_26:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L102
    mov ecx, 2
.db 0x90
    call 139636653423200
L102:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 5387
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L103
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L103:
# call_light_bif_be
    align 4
L104:
L105:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L104]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_27:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx+24]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L106
# i_func_label_L
    nop
    align 8
label_28:
# func_line_I
# i_func_info_IaaI
# kernel_refc:do_stop/3
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x4E, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_stop/3:
# i_breakpoint_trampoline
    short jmp L107
.db 0x90
    call L53
L107:
# i_test_yield
    lea rdx, qword ptr [do_stop/3+24]
    dec r14d
    long jle L54
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx+8]
    rex test dil, 1
    jne label_34
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_34
# i_get_map_element_fSSS
# skipped fetching of BEAM register
    mov rsi, qword ptr [rbx+16]
    call L68
    jne label_33
    mov qword ptr [rbx+24], rax
# i_is_tuple_of_arity_ff_ffsA
# simplified fetching of BEAM register
    mov rsi, rax
    rex test sil, 1
    jne label_32
    mov eax, dword ptr [rsi-2]
    test al, 63
    jne label_32
    cmp eax, 128
    jne label_35
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+6], 1
    vmovups xmmword ptr [rbx+24], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+32], 31
    jne label_31
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L108
    mov ecx, 4
    call 139636653423200
L108:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# i_move_sd
L109:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# line_I
# call_light_bif_be
    align 4
L110:
L111:
    long mov rcx, 9223372036854775807
    mov rax, 94068436085312
    lea rdx, qword ptr [L110]
# BIF: erlang:demonitor/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [rbx], xmm0
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# line_I
# call_light_bif_be
    align 4
L112:
L113:
    long mov rcx, 9223372036854775807
    mov rax, 94068437360368
    lea rdx, qword ptr [L112]
# BIF: maps:remove/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call any/1
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_30
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L114
    xor ecx, ecx
.db 0x90
    call 139636653423200
L114:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 75
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 24
# return
    dec r14d
    jl L63
    ret
# label_L
label_30:
# i_move_sd
    mov qword ptr [rbx+8], 11
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rsp+16], r11
# i_trim_t
    add rsp, 16
# line_I
# i_call_f
    call resource/2
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L115
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L115:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 75
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L63
    ret
# label_L
label_31:
# line_I
# i_minus_ssjd
    mov rsi, qword ptr [rbx+32]
    mov edx, 31
# is the operand small?
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L117
    mov rax, rsi
    sub rax, 16
    short jno L116
L117:
    call L118
L116:
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L119
    mov ecx, 4
.db 0x66, 0x90
    call 139636653423200
L119:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rbx+24]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# update_map_assoc_sdtI
    mov rsi, qword ptr [rbx+16]
# simplified fetching of BEAM register
    mov rdx, r10
    mov rcx, qword ptr [rbx+8]
    call L93
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L120
    mov ecx, 1
    call 139636653423200
L120:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 75
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L63
    ret
# label_L
label_32:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 907
    jne label_35
# label_L
label_33:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L121
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L121:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# line_I
# i_call_f
    call any/1
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L122
    mov ecx, 1
    call 139636653423200
L122:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L63
    ret
# label_L
label_34:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L123
    mov ecx, 2
.db 0x90
    call 139636653423200
L123:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 5387
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L124
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L124:
# call_light_bif_be
    align 4
L125:
L126:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L125]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_35:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx+24]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L106
# i_func_label_L
    nop
    align 8
label_36:
# func_line_I
# i_func_info_IaaI
# kernel_refc:cleanup/3
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x0F, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
cleanup/3:
# i_breakpoint_trampoline
    short jmp L127
.db 0x90
    call L53
L127:
# line_I
# i_test_yield
    lea rdx, qword ptr [cleanup/3+24]
    dec r14d
    long jle L54
    align 4
# bif_is_map_key_bjssd
    lea rsi, qword ptr [rbx-40]
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [rsi], rdi
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [rsi+8], rdi
# UBIF: is_map_key/2
    mov rcx, 94068437335936
    call L128
    mov qword ptr [rbx+24], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 75
    jne label_39
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L129
    mov ecx, 3
    call 139636653423200
L129:
    sub rsp, 16
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+16]
    mov qword ptr [rbx], r11
# line_I
# call_light_bif_be
    align 4
L130:
L131:
    long mov rcx, 9223372036854775807
    mov rax, 94068437360368
    lea rdx, qword ptr [L130]
# BIF: maps:remove/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# i_call_f
    call any/1
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_38
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L63
    ret
# label_L
label_38:
# i_move_sd
    mov qword ptr [rbx+8], 11
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rsp+8], r11
# i_trim_t
    add rsp, 8
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call resource/2
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L63
    ret
# label_L
label_39:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_40:
# func_line_I
# i_func_info_IaaI
# kernel_refc:any/1
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x0D, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
any/1:
# i_breakpoint_trampoline
    short jmp L132
.db 0x90
    call L53
L132:
# i_test_yield
    lea rdx, qword ptr [any/1+24]
    dec r14d
    long jle L54
    align 4
# bif_map_size_jsd
    mov rax, qword ptr [rbx]
# skipped box test since argument is always boxed
# skipped type check because the argument is always a map
L133:
L134:
    mov rax, qword ptr [rax+6]
    shl rax, 4
    or al, 15
    mov qword ptr [rbx], rax
# bif_is_ge_ssd
# simplified compare because one operand is an immediate small
    cmp qword ptr [rbx], 31
    mov eax, 75
    mov edi, 11
    cmovl rax, rdi
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_42:
# func_line_I
# i_func_info_IaaI
# kernel_refc:resource/2
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x0F, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
resource/2:
# i_breakpoint_trampoline
    short jmp L135
.db 0x90
    call L53
L135:
# i_test_yield
    lea rdx, qword ptr [resource/2+24]
    dec r14d
    long jle L54
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 39179
    short jne label_42
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L136
    mov ecx, 1
    call 139636653423200
L136:
# call_light_bif_be
    align 4
L137:
L138:
    long mov rcx, 9223372036854775807
    mov rax, 94068436122016
    lea rdx, qword ptr [L137]
# BIF: erts_internal:scheduler_wall_time/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_44:
# func_line_I
# i_func_info_IaaI
# kernel_refc:module_info/0
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L139
.db 0x90
    call L53
L139:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L54
    align 4
# i_move_sd
    mov qword ptr [rbx], 160331
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L140
    mov ecx, 1
.db 0x90
    call 139636653423200
L140:
# call_light_bif_be
    align 4
L141:
L142:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L141]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_46:
# func_line_I
# i_func_info_IaaI
# kernel_refc:module_info/1
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L143
.db 0x90
    call L53
L143:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L54
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 160331
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L144
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L144:
# call_light_bif_be
    align 4
L145:
L146:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L145]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L63
    ret
# i_func_label_L
    align 8
label_48:
# func_line_I
# i_func_info_IaaI
# kernel_refc:'-handle_info/2-fun-0-'/3
    call L51
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x72, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x3B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-handle_info/2-fun-0-'/3:
# i_breakpoint_trampoline
    short jmp L147
.db 0x90
    call L53
L147:
# i_test_yield
    lea rdx, qword ptr ['-handle_info/2-fun-0-'/3+24]
    dec r14d
    long jle L54
    align 4
# i_call_only_f
    jmp cleanup/3
# i_lambda_trampoline_FfWW
L49:
    mov rax, [rcx+14]
    mov [rbx+16], rax
    short jmp '-handle_info/2-fun-0-'/3
# int_code_end
L148:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L118:
    jmp 139636653426736
L106:
    jmp 139636653427776
L63:
    jmp 139636653422960
L128:
    jmp 139636653424168
L68:
    jmp 139636653424896
L54:
    jmp 139636653426040
L93:
    jmp 139636653428344
L91:
    jmp 139636653427096
L53:
    jmp 139636653424496
L51:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x02, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0x4F, 0x6E, 0x28, 0xB0, 0xDF, 0xA0, 0x2E, 0xEB, 0x23, 0xC4, 0xC1, 0xDF, 0x09, 0x59, 0x1D, 0x09, 0x6A, 0x68, 0x02, 0x77, 0x09, 0x62, 0x65, 0x68, 0x61, 0x76, 0x69, 0x6F, 0x75, 0x72, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x77, 0x0A, 0x67, 0x65, 0x6E, 0x5F, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x2D, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x5F, 0x72, 0x65, 0x66, 0x63, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0x09, 0x1D, 0x59, 0x09, 0xDF, 0xC1, 0xC4, 0x23, 0xEB, 0x2E, 0xA0, 0xDF, 0xB0, 0x28, 0x6E, 0x4F
.section .text {#0}
