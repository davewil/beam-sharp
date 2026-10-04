    align 8
L13:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# empty_func_line
# i_func_info_IaaI
# prim_eval:receive/2
    call L14
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x7B, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x8F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
receive/2:
# i_breakpoint_trampoline
    short jmp L15
.db 0x90
    call L16
L15:
# i_test_yield
    lea rdx, qword ptr [receive/2+24]
    dec r14d
    long jle L17
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L18
    mov ecx, 2
    call 139636653423200
L18:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# i_call_f
    call label_7
# aligned_label_Lt
    align 4
label_3:
# i_loop_rec_f
    align 4
L19:
    lea rdi, qword ptr [L19]
    lea rsi, qword ptr [label_5]
    call 139636653425768
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# i_call_fun_t
# simplified fetching of BEAM register
    mov rcx, r10
    mov edx, 276
    mov rdi, 139636653423680
    lea r8, qword ptr [L20]
    test ecx, 1
    short jne L20
    cmp word ptr [rcx-2], dx
    short jne L20
    mov rax, qword ptr [rcx+6]
    mov rdi, qword ptr [rax+r12*8]
L20:
    call rdi
.db 0x66, 0x90
    call rdi
# is_ne_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 29707
    je label_4
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
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L21
    ret
# label_L
label_4:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    jmp label_3
# aligned_label_Lt
    align 4
label_5:
# wait_timeout_locked_sf
    mov rsi, qword ptr [rsp]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rdx, qword ptr [L23]
    call 94068434776064
    mov rsp, rbp
    cmp rax, 1
    short je L22
    short jl L23
    lea rsi, qword ptr [label_5]
    xor ecx, ecx
    push rsi
    jmp L24
L22:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_3]
    call 94068434775632
    mov rsp, rbp
    jmp L25
    align 4
L23:
# timeout
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068434776496
    mov rsp, rbp
# i_move_sd
    mov qword ptr [rbx], 459
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L21
    ret
# i_func_label_L
    align 8
label_6:
# empty_func_line
# i_func_info_IaaI
# prim_eval:arg_reg_alloc/0
    call L14
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x7B, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x7C, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_7:
# i_breakpoint_trampoline
    short jmp L26
.db 0x90
    call L16
L26:
# i_test_yield
    lea rdx, qword ptr [label_7+24]
    dec r14d
    long jle L17
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L27
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L27:
# i_move_sd
    mov qword ptr [rbx], 2147483647
# call_light_bif_be
    align 4
L28:
L29:
    long mov rcx, 9223372036854775807
    mov rax, 94068436122992
    lea rdx, qword ptr [L28]
# BIF: erlang:bump_reductions/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx+24], 75
# i_move_sd
    mov qword ptr [rbx+32], 75
# i_move_sd
    mov qword ptr [rbx+16], 75
# i_move_sd
    mov qword ptr [rbx+40], 75
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx+48], 75
# i_move_sd
    mov qword ptr [rbx], 75
# i_call_last_ft
    jmp label_9
# i_func_label_L
    align 8
label_8:
# empty_func_line
# i_func_info_IaaI
# prim_eval:arg_reg_alloc/7
    call L14
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x7B, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x7C, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
label_9:
# i_breakpoint_trampoline
    short jmp L30
.db 0x90
    call L16
L30:
# i_test_yield
    lea rdx, qword ptr [label_9+24]
    dec r14d
    long jle L17
    align 4
# i_move_sd
    mov qword ptr [rbx], 32075
# return
    dec r14d
    jl L21
    ret
# i_func_label_L
    align 8
label_10:
# empty_func_line
# i_func_info_IaaI
# prim_eval:module_info/0
    call L14
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x7B, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L31
.db 0x90
    call L16
L31:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L17
    align 4
# i_move_sd
    mov qword ptr [rbx], 97227
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L32
    mov ecx, 1
.db 0x90
    call 139636653423200
L32:
# call_light_bif_be
    align 4
L33:
L34:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L33]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L21
    ret
# i_func_label_L
    align 8
label_12:
# empty_func_line
# i_func_info_IaaI
# prim_eval:module_info/1
    call L14
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x7B, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L35
.db 0x90
    call L16
L35:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L17
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 97227
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L36
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L36:
# call_light_bif_be
    align 4
L37:
L38:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L37]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L21
    ret
# int_code_end
L39:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L25:
    jmp 139636653427727
L24:
    jmp 139636653427784
L21:
    jmp 139636653422960
L17:
    jmp 139636653426040
L16:
    jmp 139636653424496
L14:
    jmp 139636653424856
.section .rodata {#1}
md5:
.db 0xD6, 0xC8, 0x9E, 0x23, 0xA4, 0x64, 0xBE, 0x67, 0xD4, 0x8D, 0xB0, 0x19, 0xC6, 0x3D, 0x54, 0xD6
.section .text {#0}
