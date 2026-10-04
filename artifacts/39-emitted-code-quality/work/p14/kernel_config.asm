    align 8
L71:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# kernel_config:start_link/0
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x42, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_link/0:
# i_breakpoint_trampoline
    short jmp L73
.db 0x90
    call L74
L73:
# i_test_yield
    lea rdx, qword ptr [start_link/0+24]
    dec r14d
    long jle L75
    align 4
# i_move_sd
    mov qword ptr [rbx+8], 59
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov qword ptr [rbx], 207563
# i_call_ext_only_e
L76:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_3:
# func_line_I
# i_func_info_IaaI
# kernel_config:init/1
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
init/1:
# i_breakpoint_trampoline
    short jmp L77
.db 0x90
    call L74
L77:
# i_test_yield
    lea rdx, qword ptr [init/1+24]
    dec r14d
    long jle L75
    align 4
# is_nil_fS
    cmp byte ptr [rbx], 59
    short jne label_3
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L78
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L78:
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx], 45387
# line_I
# call_light_bif_be
    align 4
L79:
L80:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L79]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call sync_nodes/0
# i_is_tuple_fs
    mov rsi, qword ptr [rbx]
# simplified tuple test since the source is always a tuple when boxed
    rex test sil, 1
    jne label_5
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L81
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L81:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 43019
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_5:
# i_move_sd
    mov qword ptr [rbx], 205259
# line_I
# call_light_bif_be
    align 4
L83:
L84:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094864
    lea rdx, qword ptr [L83]
# BIF: erlang:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_pid_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L85
    test al, 1
    jne label_9
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_9
L85:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L86
    mov ecx, 1
    call 139636653423200
L86:
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx+8], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 592587
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r11
# line_I
# send
    align 4
L87:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L87]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# aligned_label_Lt
    align 4
label_6:
# i_loop_rec_f
    align 4
L88:
    lea rdi, qword ptr [L88]
    lea rsi, qword ptr [label_8]
    call 139636653425768
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 592651
    jne label_7
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
# jump_f
    jmp label_9
# label_L
label_7:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    short jmp label_6
# aligned_label_Lt
    align 4
label_8:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_6]
    call 94068434775632
    mov rsp, rbp
    jmp L89
# label_L
label_9:
# i_move_sd
L90:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# i_func_label_L
    align 8
label_10:
# func_line_I
# i_func_info_IaaI
# kernel_config:handle_info/2
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x5D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_info/2:
# i_breakpoint_trampoline
    short jmp L91
.db 0x90
    call L74
L91:
# i_test_yield
    lea rdx, qword ptr [handle_info/2+24]
    dec r14d
    long jle L75
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L92
    mov ecx, 2
    call 139636653423200
L92:
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
    jl L82
    ret
# i_func_label_L
    align 8
label_12:
# func_line_I
# i_func_info_IaaI
# kernel_config:terminate/2
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x53, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
terminate/2:
# i_breakpoint_trampoline
    short jmp L93
.db 0x90
    call L74
L93:
# i_test_yield
    lea rdx, qword ptr [terminate/2+24]
    dec r14d
    long jle L75
    align 4
# i_move_sd
    mov qword ptr [rbx], 32075
# return
    dec r14d
    jl L82
    ret
# i_func_label_L
    align 8
label_14:
# func_line_I
# i_func_info_IaaI
# kernel_config:handle_call/3
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x59, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_call/3:
# i_breakpoint_trampoline
    short jmp L94
.db 0x90
    call L74
L94:
# i_test_yield
    lea rdx, qword ptr [handle_call/3+24]
    dec r14d
    long jle L75
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 592715
    short jne label_14
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L95
    mov ecx, 3
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L95:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov qword ptr [r15+16], 32075
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L82
    ret
# i_func_label_L
    align 8
label_16:
# func_line_I
# i_func_info_IaaI
# kernel_config:handle_cast/2
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x5C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_cast/2:
# i_breakpoint_trampoline
    short jmp L96
.db 0x90
    call L74
L96:
# i_test_yield
    lea rdx, qword ptr [handle_cast/2+24]
    dec r14d
    long jle L75
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 592715
    short jne label_16
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L97
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L97:
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
    jl L82
    ret
# i_func_label_L
    align 8
label_18:
# func_line_I
# i_func_info_IaaI
# kernel_config:code_change/3
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x61, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
code_change/3:
# i_breakpoint_trampoline
    short jmp L98
.db 0x90
    call L74
L98:
# i_test_yield
    lea rdx, qword ptr [code_change/3+24]
    dec r14d
    long jle L75
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L99
    mov ecx, 2
    call 139636653423200
L99:
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
    jl L82
    ret
# i_func_label_L
    align 8
label_20:
# func_line_I
# i_func_info_IaaI
# kernel_config:sync_nodes/0
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x0B, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
sync_nodes/0:
# i_breakpoint_trampoline
    short jmp L100
.db 0x90
    call L74
L100:
# i_test_yield
    lea rdx, qword ptr [sync_nodes/0+24]
    dec r14d
    long jle L75
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L101
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L101:
    sub rsp, 16
# init_yregs_I
    mov qword ptr [rsp], 59
# catch_yf
    inc qword ptr [r13+256]
L102:
    mov eax, 2147483647
    mov qword ptr [rsp+8], rax
# line_I
# i_call_f
.db 0x66, 0x90
    call get_sync_data/0
# label_L
label_22:
# catch_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+8], 59
    cmp qword ptr [rbx], 0
    short jne L103
    call 139636653422576
L103:
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# i_is_tuple_fs
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_26
    test byte ptr [rsi-2], 63
    jne label_26
# i_select_tuple_arity_SfI
# simplified fetching of BEAM register
    mov rsi, r10
# skipped box test since argument is always boxed
    mov esi, dword ptr [rsi-2]
# simplified tuple test since the source is always a tuple when boxed
    cmp esi, 128
    je label_25
    cmp esi, 192
    je label_23
    jne label_27
# label_L
label_23:
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rsp], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 395
    jne label_24
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 16
    jmp wait_nodes/2
# label_L
label_24:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L104
    mov ecx, 1
    call 139636653423200
L104:
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx+8], r10
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# append_cons_Is
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+16], rsi
# i_move_sd
    mov qword ptr [rbx+8], 106507
# i_move_sd
    mov qword ptr [rbx], 207563
# line_I
# call_light_bif_be
    align 4
L105:
L106:
    long mov rcx, 9223372036854775807
    mov rax, 94068436086464
    lea rdx, qword ptr [L105]
# BIF: erlang:spawn_link/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 16
    jmp wait_nodes/2
# label_L
label_25:
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 779
    jne label_27
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L107
    xor ecx, ecx
    call 139636653423200
L107:
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
L108:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L109:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L82
    ret
# label_L
label_26:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rsp+8], 907
    jne label_27
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L82
    ret
# label_L
label_27:
# line_I
# case_end_s
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L110
# i_func_label_L
    nop
    align 8
label_28:
# func_line_I
# i_func_info_IaaI
# kernel_config:send_timeout/2
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xA0, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
send_timeout/2:
# i_breakpoint_trampoline
    short jmp L111
.db 0x90
    call L74
L111:
# i_test_yield
    lea rdx, qword ptr [send_timeout/2+24]
    dec r14d
    long jle L75
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L112
    mov ecx, 2
    call 139636653423200
L112:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# aligned_label_Lt
    align 4
label_30:
# wait_timeout_unlocked_sf
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068434775568
    mov rsp, rbp
    mov rsi, qword ptr [rbx]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rdx, qword ptr [L114]
    call 94068434776064
    mov rsp, rbp
    cmp rax, 1
    short je L113
    short jl L114
    lea rsi, qword ptr [label_30]
    xor ecx, ecx
    push rsi
    jmp L115
L113:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_30]
    call 94068434775632
    mov rsp, rbp
    jmp L89
    align 4
L114:
# timeout
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068434776496
    mov rsp, rbp
# i_move_sd
    mov qword ptr [rbx+8], 459
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# line_I
# send
    align 4
L116:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L116]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L82
    ret
# i_func_label_L
    align 8
label_31:
# func_line_I
# i_func_info_IaaI
# kernel_config:wait_nodes/2
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x0B, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
wait_nodes/2:
# i_breakpoint_trampoline
    short jmp L117
.db 0x90
    call L74
L117:
# i_test_yield
    lea rdx, qword ptr [wait_nodes/2+24]
    dec r14d
    long jle L75
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L118
    mov ecx, 2
    call 139636653423200
L118:
    sub rsp, 24
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov qword ptr [rbx], 75
# line_I
# i_call_ext_e
L119:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_34
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L120
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L120:
# i_move_sd
L121:
    long mov rdi, 9223372036854775807
    mov qword ptr [rsp], rdi
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+8], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L122:
L123:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L122]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_trim_t
    add rsp, 8
# line_I
# i_call_ext_e
L124:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx], xmm0
# init_yregs_I
    mov qword ptr [rsp+8], 59
# i_trim_t
    add rsp, 8
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call rec_nodes/2
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov qword ptr [rbx], 11
# line_I
# i_call_ext_e
L125:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_33
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L82
    ret
# label_L
label_33:
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L110
# label_L
label_34:
# line_I
    nop
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L110
# i_func_label_L
    nop
    align 8
label_35:
# func_line_I
# i_func_info_IaaI
# kernel_config:rec_nodes/2
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0xF8, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
rec_nodes/2:
# i_breakpoint_trampoline
    short jmp L126
.db 0x90
    call L74
L126:
# i_test_yield
    lea rdx, qword ptr [rec_nodes/2+24]
    dec r14d
    long jle L75
    align 4
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_37
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    jne label_37
# i_move_sd
    mov qword ptr [rbx], 32075
# return
    dec r14d
    jl L82
    ret
# label_L
label_37:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L127
    mov ecx, 2
    call 139636653423200
L127:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# aligned_label_Lt
    align 4
label_38:
# i_loop_rec_f
    align 4
L128:
    lea rdi, qword ptr [L128]
    lea rsi, qword ptr [label_42]
    call 139636653425768
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_39
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_39
    cmp edi, 128
    jne label_41
    cmp qword ptr [rsi+6], 30219
    jne label_41
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
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_call_last_ft
    add rsp, 16
    jmp check_up/3
# label_L
label_39:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 459
    jne label_41
# is_nil_fS
    cmp byte ptr [rsp+8], 59
    jne label_40
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
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L82
    ret
# label_L
label_40:
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L129
    xor ecx, ecx
    call 139636653423200
L129:
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
    mov qword ptr [r15+8], 592907
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 779
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L82
    ret
# label_L
label_41:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    jmp label_38
# aligned_label_Lt
    align 4
label_42:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_38]
    call 94068434775632
    mov rsp, rbp
    jmp L89
# i_func_label_L
    align 8
label_43:
# func_line_I
# i_func_info_IaaI
# kernel_config:check_up/3
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x0C, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
check_up/3:
# i_breakpoint_trampoline
    short jmp L130
.db 0x90
    call L74
L130:
# i_test_yield
    lea rdx, qword ptr [check_up/3+24]
    dec r14d
    long jle L75
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L131
    mov ecx, 3
    call 139636653423200
L131:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# line_I
# call_light_bif_be
    align 4
L132:
L133:
    long mov rcx, 9223372036854775807
    mov rax, 94068435892832
    lea rdx, qword ptr [L132]
# BIF: lists:member/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_45
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+8], 1
    vmovups xmmword ptr [rbx], xmm0
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rsp+16], r10
# i_trim_t
    add rsp, 16
# line_I
# i_call_ext_e
L134:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_call_last_ft
    add rsp, 8
    jmp rec_nodes/2
# label_L
label_45:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+16]
    mov qword ptr [rbx], r11
# line_I
# call_light_bif_be
    align 4
L135:
L136:
    long mov rcx, 9223372036854775807
    mov rax, 94068435892832
    lea rdx, qword ptr [L135]
# BIF: lists:member/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_46
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+16]
    mov qword ptr [rbx], r11
# i_move_sd
    mov rdx, qword ptr [rsp+8]
    mov qword ptr [rsp+16], rdx
# i_trim_t
    add rsp, 16
# line_I
# i_call_ext_e
L137:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp rec_nodes/2
# label_L
label_46:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 24
    jmp rec_nodes/2
# i_func_label_L
    align 8
label_47:
# func_line_I
# i_func_info_IaaI
# kernel_config:get_sync_data/0
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x0C, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_sync_data/0:
# i_breakpoint_trampoline
    short jmp L138
.db 0x90
    call L74
L138:
# i_test_yield
    lea rdx, qword ptr [get_sync_data/0+24]
    dec r14d
    long jle L75
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L139
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L139:
    sub rsp, 16
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call get_sync_timeout/0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call get_sync_mandatory_nodes/0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# i_call_f
    call get_sync_optional_nodes/0
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L140
    mov ecx, 1
    call 139636653423200
L140:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
# (moving and swapping two elements at once)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [r15+8], xmm0
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L82
    ret
# i_func_label_L
    align 8
label_49:
# func_line_I
# i_func_info_IaaI
# kernel_config:get_sync_timeout/0
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x0C, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_sync_timeout/0:
# i_breakpoint_trampoline
    short jmp L141
.db 0x90
    call L74
L141:
# i_test_yield
    lea rdx, qword ptr [get_sync_timeout/0+24]
    dec r14d
    long jle L75
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L142
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L142:
# i_move_sd
    mov qword ptr [rbx], 593163
# line_I
# i_call_ext_e
L143:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_53
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_53
    cmp edi, 128
    jne label_54
    cmp qword ptr [rsi+6], 32075
    jne label_54
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_integer_fs
# simplified fetching of BEAM register
    mov rdi, r10
    mov eax, edi
    and al, 15
    cmp al, 15
    short je L144
    test al, 1
    jne label_51
    mov eax, dword ptr [rdi-2]
    and al, 59
    cmp al, 8
    jne label_51
L144:
# is_ge_fss
    mov esi, 31
# simplified fetching of BEAM register
    mov rdi, r10
# simplified small test for known integer
    rex test dil, 1
    short jne L146
    mov eax, dword ptr [rdi-2]
    test al, 4
    jne label_52
    short jmp L148
L146:
    cmp rdi, rsi
L145:
L147:
    jl label_52
L148:
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_51:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 395
    jne label_52
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_52:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L149
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L149:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 593163
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 5643
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 779
# simplified fetching of BEAM register
    mov rdi, r11
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov qword ptr [rbx], 715
# line_I
# call_light_bif_be
    align 4
L150:
L151:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091248
    lea rdx, qword ptr [L150]
# BIF: erlang:raise/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_53:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 907
    jne label_54
# i_move_sd
    mov qword ptr [rbx+8], 907
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov qword ptr [rbx], 715
# line_I
# call_light_bif_be
    align 4
L152:
L153:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091248
    lea rdx, qword ptr [L152]
# BIF: erlang:raise/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_54:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L110
# i_func_label_L
    nop
    align 8
label_55:
# func_line_I
# i_func_info_IaaI
# kernel_config:get_sync_mandatory_nodes/0
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x0D, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_sync_mandatory_nodes/0:
# i_breakpoint_trampoline
    short jmp L154
.db 0x90
    call L74
L154:
# i_test_yield
    lea rdx, qword ptr [get_sync_mandatory_nodes/0+24]
    dec r14d
    long jle L75
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L155
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L155:
# i_move_sd
    mov qword ptr [rbx], 593291
# line_I
# i_call_ext_e
L156:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_58
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_58
    cmp edi, 128
    jne label_59
    cmp qword ptr [rsi+6], 32075
    jne label_59
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_list_fs
# simplified fetching of BEAM register
    mov rax, r10
    cmp rax, 59
    short je L157
    test al, 2
    jne label_57
L157:
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_57:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L158
    mov ecx, 1
.db 0x90
    call 139636653423200
L158:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 593291
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 5643
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 779
# simplified fetching of BEAM register
    mov rdi, r11
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov qword ptr [rbx], 715
# line_I
# call_light_bif_be
    align 4
L159:
L160:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091248
    lea rdx, qword ptr [L159]
# BIF: erlang:raise/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_58:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 907
    jne label_59
# i_move_sd
    mov qword ptr [rbx], 59
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_59:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L110
# i_func_label_L
    nop
    align 8
label_60:
# func_line_I
# i_func_info_IaaI
# kernel_config:get_sync_optional_nodes/0
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x0D, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_sync_optional_nodes/0:
# i_breakpoint_trampoline
    short jmp L161
.db 0x90
    call L74
L161:
# i_test_yield
    lea rdx, qword ptr [get_sync_optional_nodes/0+24]
    dec r14d
    long jle L75
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L162
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L162:
# i_move_sd
    mov qword ptr [rbx], 593419
# line_I
# i_call_ext_e
L163:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_63
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_63
    cmp edi, 128
    jne label_64
    cmp qword ptr [rsi+6], 32075
    jne label_64
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_list_fs
# simplified fetching of BEAM register
    mov rax, r10
    cmp rax, 59
    short je L164
    test al, 2
    jne label_62
L164:
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_62:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L165
    mov ecx, 1
.db 0x90
    call 139636653423200
L165:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 593419
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 5643
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 779
# simplified fetching of BEAM register
    mov rdi, r11
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov qword ptr [rbx], 715
# line_I
# call_light_bif_be
    align 4
L166:
L167:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091248
    lea rdx, qword ptr [L166]
# BIF: erlang:raise/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_63:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 907
    jne label_64
# i_move_sd
    mov qword ptr [rbx], 59
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# label_L
label_64:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L110
# i_func_label_L
    nop
    align 8
label_65:
# func_line_I
# i_func_info_IaaI
# kernel_config:module_info/0
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L168
.db 0x90
    call L74
L168:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L75
    align 4
# i_move_sd
    mov qword ptr [rbx], 207563
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L169
    mov ecx, 1
.db 0x90
    call 139636653423200
L169:
# call_light_bif_be
    align 4
L170:
L171:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L170]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# i_func_label_L
    align 8
label_67:
# func_line_I
# i_func_info_IaaI
# kernel_config:module_info/1
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L172
.db 0x90
    call L74
L172:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L75
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 207563
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L173
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L173:
# call_light_bif_be
    align 4
L174:
L175:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L174]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L82
    ret
# i_func_label_L
    align 8
label_69:
# func_line_I
# i_func_info_IaaI
# kernel_config:'-wait_nodes/2-fun-0-'/1
    call L72
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x2A, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x0E, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-wait_nodes/2-fun-0-'/1:
# i_breakpoint_trampoline
    short jmp L176
.db 0x90
    call L74
L176:
# i_test_yield
    lea rdx, qword ptr ['-wait_nodes/2-fun-0-'/1+24]
    dec r14d
    long jle L75
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L177
    mov ecx, 1
    call 139636653423200
L177:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# i_call_ext_e
L178:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 593611
    jne label_71
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L179
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L179:
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 30219
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r11
# line_I
# send
    align 4
L180:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L180]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L82
    ret
# label_L
label_71:
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L82
    ret
# int_code_end
L181:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L115:
    jmp 139636653427784
L110:
    jmp 139636653427776
L89:
    jmp 139636653427727
L82:
    jmp 139636653422960
L75:
    jmp 139636653426040
L74:
    jmp 139636653424496
L72:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x02, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0x88, 0xE7, 0xE3, 0x5F, 0x07, 0x72, 0x66, 0x10, 0x3D, 0x0B, 0xD8, 0xBE, 0x76, 0xD3, 0xC3, 0x1D, 0x6A, 0x68, 0x02, 0x77, 0x09, 0x62, 0x65, 0x68, 0x61, 0x76, 0x69, 0x6F, 0x75, 0x72, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x77, 0x0A, 0x67, 0x65, 0x6E, 0x5F, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x2F, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x5F, 0x63, 0x6F, 0x6E, 0x66, 0x69, 0x67, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0x1D, 0xC3, 0xD3, 0x76, 0xBE, 0xD8, 0x0B, 0x3D, 0x10, 0x66, 0x72, 0x07, 0x5F, 0xE3, 0xE7, 0x88
.section .text {#0}
