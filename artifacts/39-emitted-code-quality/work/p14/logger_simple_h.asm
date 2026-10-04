    align 8
L107:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:adding_handler/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x14, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
adding_handler/1:
# i_breakpoint_trampoline
    short jmp L109
.db 0x90
    call L110
L109:
# i_test_yield
    lea rdx, qword ptr [adding_handler/1+24]
    dec r14d
    long jle L111
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    short jne label_1
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    short jne label_1
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 21387
    mov rdx, -6053264532420382264
    call L112
    short jne label_1
    mov qword ptr [rbx+8], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 400843
    short jne label_1
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L113
    mov ecx, 1
    call 139636653423200
L113:
    sub rsp, 24
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# self_d
    mov r11, qword ptr [r13]
    mov qword ptr [rsp+8], r11
# i_move_sd
    mov qword ptr [rbx], 204747
# line_I
# call_light_bif_be
    align 4
L114:
L115:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094864
    lea rdx, qword ptr [L114]
# BIF: erlang:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 907
    jne label_8
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L116
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L116:
# i_make_fun3_FStt
L117:
    long mov rax, 9223372036854775807
# Create fun thing
    mov qword ptr [r15], 65556
    mov qword ptr [r15+8], rax
# Move fun environment
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea rax, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], rax
# i_move_sd
L118:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# init_yregs_I
    mov qword ptr [rsp+8], 59
# line_I
# i_call_ext_e
L119:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_9
    cmp dword ptr [rsi-2], 128
    jne label_9
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+6], 1
    vmovups xmmword ptr [rsp], xmm0
# aligned_label_Lt
    align 4
label_3:
# i_loop_rec_f
    align 4
L120:
    lea rdi, qword ptr [L120]
    lea rsi, qword ptr [label_7]
    call 139636653425768
# i_select_tuple_arity_SfI
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_6
    mov esi, dword ptr [rsi-2]
    rex test sil, 63
    jne label_6
    cmp esi, 128
    je label_5
    cmp esi, 320
    je label_4
    jne label_6
# label_L
label_4:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+22]
    vmovups xmmword ptr [rbx+24], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 1355
    jne label_6
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 35211
    jne label_6
# is_eq_exact_fss
    mov rsi, qword ptr [rsp]
    mov rdi, qword ptr [rbx+16]
    cmp rdi, rsi
    short je L121
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    je label_6
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_6
L121:
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+8]
    mov rdi, qword ptr [rbx+32]
    cmp rdi, rsi
    short je L122
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    je label_6
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_6
L122:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L123
    mov ecx, 1
    call 139636653423200
L123:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+38]
    mov qword ptr [rbx], r10
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
    mov qword ptr [r15+8], 779
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
    jl L124
    ret
# label_L
label_5:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+6], 1
    vmovups xmmword ptr [rbx], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 80907
    jne label_6
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+8]
    mov rdi, qword ptr [rbx+8]
    cmp rdi, rsi
    short je L125
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    je label_6
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_6
L125:
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
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 16
# line_I
# call_light_bif_be
    align 4
L126:
L127:
    long mov rcx, 9223372036854775807
    mov rax, 94068436085024
    lea rdx, qword ptr [L126]
# BIF: erlang:demonitor/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L128
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L128:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 32075
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
    jl L124
    ret
# label_L
label_6:
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
label_7:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_3]
    call 94068434775632
    mov rsp, rbp
    jmp L129
# label_L
label_8:
# i_move_sd
L130:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
    add rsp, 24
# return
    dec r14d
    jl L124
    ret
# label_L
label_9:
# line_I
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L131
# i_func_label_L
    nop
    align 8
label_10:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:removing_handler/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x14, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
removing_handler/1:
# i_breakpoint_trampoline
    short jmp L132
.db 0x90
    call L110
L132:
# i_test_yield
    lea rdx, qword ptr [removing_handler/1+24]
    dec r14d
    long jle L111
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    short jne label_10
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    short jne label_10
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 21387
    mov rdx, -6053264532420382264
    call L112
    short jne label_10
    mov qword ptr [rbx+8], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 400843
    short jne label_10
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L133
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L133:
    sub rsp, 16
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# i_move_sd
    mov qword ptr [rbx], 204747
# line_I
# call_light_bif_be
    align 4
L134:
L135:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094864
    lea rdx, qword ptr [L134]
# BIF: erlang:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 907
    jne label_12
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L124
    ret
# label_L
label_12:
# recv_marker_reserve_S
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435275792
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov qword ptr [rsp], rax
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 35211
# line_I
# call_light_bif_be
    align 4
L136:
L137:
    long mov rcx, 9223372036854775807
    mov rax, 94068436086224
    lea rdx, qword ptr [L136]
# BIF: erlang:monitor/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# recv_marker_bind_SS
    mov rsi, qword ptr [rsp]
    mov rdx, qword ptr [rbx]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435276384
    mov rsp, rbp
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# i_move_sd
    mov qword ptr [rbx+8], 43019
# line_I
# send
    align 4
L138:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L138]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# recv_marker_use_S
    mov rsi, qword ptr [rsp]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274800
    mov rsp, rbp
# aligned_label_Lt
    align 4
label_13:
# i_loop_rec_f
    align 4
L139:
    lea rdi, qword ptr [L139]
    lea rsi, qword ptr [label_15]
    call 139636653425768
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_14
    cmp dword ptr [rsi-2], 320
    jne label_14
    cmp qword ptr [rsi+6], 1355
    jne label_14
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rbx+8], xmm0
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 35211
    jne label_14
# is_eq_exact_fss
    mov rsi, qword ptr [rsp]
    mov rdi, qword ptr [rbx+8]
    cmp rdi, rsi
    short je L140
    rex test dil, 1
    jne label_14
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_14
L140:
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+8]
    mov rdi, qword ptr [rbx]
    cmp rdi, rsi
    short je L141
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    je label_14
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_14
L141:
# recv_marker_clear_S
    mov rsi, qword ptr [rsp]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435276112
    mov rsp, rbp
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
    jl L124
    ret
# label_L
label_14:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    jmp label_13
# aligned_label_Lt
    align 4
label_15:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_13]
    call 94068434775632
    mov rsp, rbp
    jmp L129
# i_func_label_L
    align 8
label_16:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:log/2
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xDD, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
log/2:
# i_breakpoint_trampoline
    short jmp L142
.db 0x90
    call L110
L142:
# i_test_yield
    lea rdx, qword ptr [log/2+24]
    dec r14d
    long jle L111
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_20
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_20
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 26827
    mov rdx, -8234312153975418458
    call L112
    jne label_20
    mov qword ptr [rbx+8], rax
# is_map_fs
# simplified fetching of BEAM register
    mov rdi, rax
    rex test dil, 1
    jne label_20
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_20
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx+8]
    mov esi, 15691
    mov rdx, -8521787742890970463
    call L112
    jne label_20
    mov qword ptr [rbx+8], rax
# is_map_fs
# simplified fetching of BEAM register
    mov rdi, rax
    rex test dil, 1
    jne label_20
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_20
# i_get_map_elements_fsI
.section .rodata {#1}
L145:
    align 8
.db 0x0B, 0xAC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x23, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0xC6, 0xBC, 0x59, 0x99, 0x8A, 0x8A, 0x05, 0xD5
    align 8
.db 0x4B, 0xB2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x13, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x07, 0x33, 0xFC, 0x82, 0xEC, 0x8A, 0xA6, 0xA8
.section .text {#0}
    mov rdi, qword ptr [rbx+8]
# simplified multi-element lookup
    mov eax, dword ptr [rdi-2]
    and al, 252
    cmp al, 44
    jne L143
    mov eax, dword ptr [rdi+6]
    mov rsi, qword ptr [rdi+14]
L146:
    dec eax
    jl label_20
    cmp qword ptr [rsi+rax*8+6], 45643
    short jne L146
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+8], rdx
L147:
    dec eax
    jl label_20
    cmp qword ptr [rsi+rax*8+6], 44043
    short jne L147
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+16], rdx
    short jmp L144
L143:
    mov ecx, 2
    lea r8, qword ptr [L145]
    mov rdx, rsp
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rbx
    call 94068434772192
    mov rsp, rbp
    test rax, rax
    je label_20
L144:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 230603
    jne label_20
# is_ne_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 230731
    je label_20
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L148
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L148:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov qword ptr [rbx+8], 204747
# i_move_sd
    mov qword ptr [rbx], 81611
# line_I
# i_call_ext_e
L149:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_19
    cmp rsi, 75
    je label_18
    jmp label_21
# label_L
label_18:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 8
    jmp do_log/1
# label_L
label_19:
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L124
    ret
# label_L
label_20:
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L150
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L150:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call do_log/1
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# label_L
label_21:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L131
# i_func_label_L
    nop
    align 8
label_22:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:do_log/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x14, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_log/1:
# i_breakpoint_trampoline
    short jmp L151
.db 0x90
    call L110
L151:
# i_test_yield
    lea rdx, qword ptr [do_log/1+24]
    dec r14d
    long jle L111
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_27
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_27
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 26827
    mov rdx, -8234312153975418458
    call L112
    jne label_27
    mov qword ptr [rbx+8], rax
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx]
    mov esi, 132875
    mov rdx, -8264194884121781716
    call L112
    jne label_27
# is_map_fs
    mov rdi, qword ptr [rbx+8]
    rex test dil, 1
    jne label_27
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_27
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 52363
    mov rdx, -5706953854613786758
    call L112
    jne label_27
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L152
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L152:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov qword ptr [rbx], 204747
# line_I
# call_light_bif_be
    align 4
L153:
L154:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094864
    lea rdx, qword ptr [L153]
# BIF: erlang:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 907
    jne label_26
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rsp]
    mov esi, 412811
    mov rdx, -4785504758576007764
    call L112
    jne label_24
    mov qword ptr [rbx], rax
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, rax
    cmp rsi, 11
    je label_24
    cmp rsi, 75
    je label_25
    jmp label_28
# label_L
label_24:
# init_yregs_I
    mov qword ptr [rsp], 59
# line_I
# i_call_ext_e
L155:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L156
    mov ecx, 1
    call 139636653423200
L156:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 1
L157:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
    lea rdi, byte ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], rdi
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L158
    mov ecx, 1
.db 0x90
    call 139636653423200
L158:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 3
L159:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
L160:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+32], rdi
    mov qword ptr [r15+40], 779
    lea rdi, byte ptr [r15+2]
    add r15, 48
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 400843
# line_I
# i_call_f
.db 0x66, 0x90
    call log_internal/2
# label_L
label_25:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 400843
# i_call_last_ft
    add rsp, 16
    jmp log_internal/2
# label_L
label_26:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L161
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L161:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 56651
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 204747
# line_I
# send
    align 4
L162:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L162]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L124
    ret
# label_L
label_27:
# i_move_sd
    mov qword ptr [rbx], 32075
# return
    dec r14d
    jl L124
    ret
# label_L
label_28:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L131
# i_func_label_L
    nop
    align 8
label_29:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:init/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
init/1:
# i_breakpoint_trampoline
    short jmp L163
.db 0x90
    call L110
L163:
# i_test_yield
    lea rdx, qword ptr [init/1+24]
    dec r14d
    long jle L111
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L164
    mov ecx, 1
    call 139636653423200
L164:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# self_d
    mov r11, qword ptr [r13]
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov qword ptr [rbx], 204747
# line_I
# call_light_bif_be
    align 4
L165:
L166:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094720
    lea rdx, qword ptr [L165]
# BIF: erlang:register/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L167
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L167:
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+8], rdi
    mov qword ptr [r15+16], 80907
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r11
# i_move_sd
    mov rdx, qword ptr [rsp]
    mov qword ptr [rbx], rdx
# i_trim_t
    add rsp, 8
# line_I
# send
    align 4
L168:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L168]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
L169:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 414923
# i_call_last_ft
    jmp loop/2
# i_func_label_L
    align 8
label_31:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:loop/2
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x4B, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
loop/2:
# i_breakpoint_trampoline
    short jmp L170
.db 0x90
    call L110
L170:
# i_test_yield
    lea rdx, qword ptr [loop/2+24]
    dec r14d
    long jle L111
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L171
    mov ecx, 2
    call 139636653423200
L171:
    sub rsp, 24
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+8], xmm0
# aligned_label_Lt
    align 4
label_33:
# i_loop_rec_f
    align 4
L172:
    lea rdi, qword ptr [L172]
    lea rsi, qword ptr [label_38]
    call 139636653425768
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_35
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_35
    cmp edi, 128
    jne label_37
    cmp qword ptr [rsi+6], 56651
    jne label_37
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_map_fs
# simplified fetching of BEAM register
    mov rdi, r10
    rex test dil, 1
    jne label_37
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_37
# i_get_map_element_hash_fScWS
# simplified fetching of BEAM register
    mov rdi, r10
    mov esi, 26827
    mov rdx, -8234312153975418458
    call L112
    jne label_37
    mov qword ptr [rbx+8], rax
# is_map_fs
# simplified fetching of BEAM register
    mov rdi, rax
    rex test dil, 1
    jne label_37
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_37
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx+8]
    mov esi, 15691
    mov rdx, -8521787742890970463
    call L112
    jne label_34
    mov qword ptr [rbx+16], rax
# is_map_fs
# simplified fetching of BEAM register
    mov rdi, rax
    rex test dil, 1
    jne label_34
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_34
# i_get_map_elements_fsI
.section .rodata {#1}
L175:
    align 8
.db 0x0B, 0xAC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x33, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0xC6, 0xBC, 0x59, 0x99, 0x8A, 0x8A, 0x05, 0xD5
    align 8
.db 0x4B, 0xB2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x23, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x07, 0x33, 0xFC, 0x82, 0xEC, 0x8A, 0xA6, 0xA8
.section .text {#0}
    mov rdi, qword ptr [rbx+16]
# simplified multi-element lookup
    mov eax, dword ptr [rdi-2]
    and al, 252
    cmp al, 44
    jne L173
    mov eax, dword ptr [rdi+6]
    mov rsi, qword ptr [rdi+14]
L176:
    dec eax
    jl label_34
    cmp qword ptr [rsi+rax*8+6], 45643
    short jne L176
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+16], rdx
L177:
    dec eax
    jl label_34
    cmp qword ptr [rsi+rax*8+6], 44043
    short jne L177
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+24], rdx
    short jmp L174
L173:
    mov ecx, 2
    lea r8, qword ptr [L175]
    mov rdx, rsp
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rbx
    call 94068434772192
    mov rsp, rbp
    test rax, rax
    je label_34
L174:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 230603
    jne label_34
# is_ne_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 230731
    je label_34
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
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
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 16
# line_I
# i_call_f
.db 0x66, 0x90
    call update_buffer/2
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp loop/2
# label_L
label_34:
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx+8]
    mov esi, 52363
    mov rdx, -5706953854613786758
    call L112
    jne label_37
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx]
    mov esi, 132875
    mov rdx, -8264194884121781716
    call L112
    jne label_37
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
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
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+16]
    mov qword ptr [rbx], r11
# init_yregs_I
    mov qword ptr [rsp+16], 59
# line_I
# i_call_f
.db 0x90
    call log_internal/2
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+16], r11
# i_move_sd
    mov rdx, qword ptr [rsp]
    mov qword ptr [rbx+8], rdx
# i_trim_t
    add rsp, 16
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call update_buffer/2
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp loop/2
# label_L
label_35:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 43019
    jne label_37
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
# init_yregs_I
    mov qword ptr [rsp+16], 59
# i_move_sd
    mov qword ptr [rbx], 11723
# line_I
# i_call_ext_e
L178:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_36
    cmp dword ptr [rsi-2], 128
    jne label_36
    cmp qword ptr [rsi+6], 32075
    jne label_36
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# init_yregs_I
    mov qword ptr [rsp+8], 59
# line_I
# i_call_f
.db 0x66, 0x90
    call replay_buffer/1
# label_L
label_36:
# i_move_sd
    mov qword ptr [rbx], 25099
# line_I
# call_light_bif_be
    align 4
L179:
L180:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094864
    lea rdx, qword ptr [L179]
# BIF: erlang:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# call_light_bif_be
    align 4
L181:
L182:
    long mov rcx, 9223372036854775807
    mov rax, 94068436088704
    lea rdx, qword ptr [L181]
# BIF: erlang:unlink/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 24
# return
    dec r14d
    jl L124
    ret
# label_L
label_37:
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
    vpermilpd xmm0, xmmword ptr [rsp+8], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 24
    jmp loop/2
# aligned_label_Lt
    align 4
label_38:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_33]
    call 94068434775632
    mov rsp, rbp
    jmp L129
# i_func_label_L
    align 8
label_39:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:update_buffer/2
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x55, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
update_buffer/2:
# i_breakpoint_trampoline
    short jmp L183
.db 0x90
    call L110
L183:
# i_test_yield
    lea rdx, qword ptr [update_buffer/2+24]
    dec r14d
    long jle L111
    align 4
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx]
    mov esi, 415051
    mov rdx, 5285027295610254444
    call L112
    short jne label_39
    mov qword ptr [rbx+16], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 15
    jne label_41
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx]
    mov esi, 415115
    mov rdx, 6110748445590605569
    call L112
    jne label_41
    mov qword ptr [rbx+24], rax
# line_I
# i_plus_ssjd
# simplified fetching of BEAM register
    mov rsi, rax
    mov edx, 31
# is the operand small?
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L185
    lea rax, qword ptr [rsi-15]
    add rax, rdx
    short jno L184
L185:
    call L186
L184:
    mov qword ptr [rbx+8], rax
# update_map_assoc_sdtI
    mov esi, 415115
# simplified fetching of BEAM register
    mov rdx, rax
    mov rcx, qword ptr [rbx]
    call L187
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L124
    ret
# label_L
label_41:
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx]
    mov esi, 103499
    mov rdx, -701205866032055434
    call L112
    jne label_39
    mov qword ptr [rbx+24], rax
# line_I
# i_minus_ssjd
    mov rsi, qword ptr [rbx+16]
    mov edx, 31
# is the operand small?
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L189
    mov rax, rsi
    sub rax, 16
    short jno L188
L189:
    call L190
L188:
    mov qword ptr [rbx+16], rax
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L191
    mov ecx, 4
.db 0x90
    call 139636653423200
L191:
# put_cons_ss
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx+24]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# update_map_assoc_sdtI
.section .rodata {#1}
L192:
    align 8
.db 0x4B, 0x94, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x13, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x4B, 0x55, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x23, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
    mov rdi, qword ptr [rbx]
    mov qword ptr [rbx+24], rdi
    mov edx, 3
    mov ecx, 4
    lea r8, qword ptr [L192]
.db 0x0F, 0x1F, 0x00
    call 139636653428168
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L124
    ret
# i_func_label_L
    align 8
label_42:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:replay_buffer/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x55, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
replay_buffer/1:
# i_breakpoint_trampoline
    short jmp L193
.db 0x90
    call L110
L193:
# i_test_yield
    lea rdx, qword ptr [replay_buffer/1+24]
    dec r14d
    long jle L111
    align 4
# i_get_map_elements_fsI
.section .rodata {#1}
L196:
    align 8
.db 0x4B, 0x94, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x13, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x76, 0x3B, 0xBD, 0xE0, 0xFA, 0xD0, 0x44, 0xF6
    align 8
.db 0x8B, 0x55, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x23, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x01, 0xCF, 0x32, 0xCB, 0x55, 0xBD, 0xCD, 0x54
.section .text {#0}
    mov rdi, qword ptr [rbx]
# simplified multi-element lookup
    mov eax, dword ptr [rdi-2]
    and al, 252
    cmp al, 44
    jne L194
    mov eax, dword ptr [rdi+6]
    mov rsi, qword ptr [rdi+14]
L197:
    dec eax
    short jl label_42
    cmp qword ptr [rsi+rax*8+6], 415115
    short jne L197
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+16], rdx
L198:
    dec eax
    short jl label_42
    cmp qword ptr [rsi+rax*8+6], 103499
    short jne L198
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+8], rdx
    short jmp L195
L194:
    mov ecx, 2
    lea r8, qword ptr [L196]
    mov rdx, rsp
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rbx
    call 94068434772192
    mov rsp, rbp
    test rax, rax
    je label_42
L195:
# allocate_heap_tIt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L199
    mov ecx, 3
.db 0x90
    call 139636653423200
L199:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+8], r10
# i_move_sd
L200:
    long mov rdi, 9223372036854775807
    mov qword ptr [rsp], rdi
# i_move_sd
    mov r11, qword ptr [rbx+16]
    mov qword ptr [rbx], r11
# line_I
# i_call_f
.db 0x90
    call drop_msg/1
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# i_move_sd
    mov rdx, qword ptr [rsp]
    mov qword ptr [rsp+8], rdx
# i_trim_t
    add rsp, 8
# call_light_bif_be
    align 4
L201:
L202:
    long mov rcx, 9223372036854775807
    mov rax, 94068435893280
    lea rdx, qword ptr [L201]
# BIF: lists:reverse/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_ext_last_et
    add rsp, 8
L203:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_44:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:drop_msg/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x56, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
drop_msg/1:
# i_breakpoint_trampoline
    short jmp L204
.db 0x90
    call L110
L204:
# i_test_yield
    lea rdx, qword ptr [drop_msg/1+24]
    dec r14d
    long jle L111
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 15
    jne label_46
# i_move_sd
    mov qword ptr [rbx], 59
# return
    dec r14d
    jl L124
    ret
# label_L
label_46:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L205
    mov ecx, 1
.db 0x90
    call 139636653423200
L205:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# i_call_ext_e
L206:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L207
    mov ecx, 1
    call 139636653423200
L207:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 1
L208:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
    lea rdi, byte ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], rdi
# test_heap_It
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L209
    mov ecx, 1
.db 0x90
    call 139636653423200
L209:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
L210:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+8], rdi
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L211
    mov ecx, 2
.db 0x90
    call 139636653423200
L211:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 3
L212:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
# (initializing two elements at once)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15+24], xmm0
    mov qword ptr [r15+40], 22027
    lea rdi, byte ptr [r15+2]
    add r15, 48
    mov qword ptr [rbx], rdi
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L213
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L213:
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L124
    ret
# i_func_label_L
    align 8
label_47:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:log_internal/2
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x56, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
log_internal/2:
# i_breakpoint_trampoline
    short jmp L214
.db 0x90
    call L110
L214:
# i_test_yield
    lea rdx, qword ptr [log_internal/2+24]
    dec r14d
    long jle L111
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 400843
    jne label_49
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L215
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L215:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
    call display_log/1
# i_move_sd
    mov qword ptr [rbx], 400843
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# label_L
label_49:
# allocate_heap_tIt
    lea rdx, qword ptr [r15+96]
    cmp rdx, rsp
    short jbe L216
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L216:
    sub rsp, 40
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+24], xmm0
# i_make_fun3_FStt
L217:
    long mov rax, 9223372036854775807
# Create fun thing
    mov qword ptr [r15], 65556
    mov qword ptr [r15+8], rax
# Move fun environment
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea rax, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], rax
# recv_marker_reserve_S
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435275792
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov qword ptr [rsp+16], rax
# line_I
# i_call_ext_e
L218:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rsp+8], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp], rsi
# recv_marker_bind_SS
    mov rsi, qword ptr [rsp+16]
# simplified fetching of BEAM register
    mov rdx, r10
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435276384
    mov rsp, rbp
# recv_marker_use_S
    mov rsi, qword ptr [rsp+8]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274800
    mov rsp, rbp
# aligned_label_Lt
    align 4
label_50:
# i_loop_rec_f
    align 4
L219:
    lea rdi, qword ptr [L219]
    lea rsi, qword ptr [label_53]
    call 139636653425768
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_52
    cmp dword ptr [rsi-2], 320
    jne label_52
    cmp qword ptr [rsi+6], 1355
    jne label_52
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+38]
    mov qword ptr [rbx], r11
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r11, 523
    jne label_51
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+8]
# simplified fetching of BEAM register
    mov rdi, r10
    cmp rdi, rsi
    short je L220
    rex test dil, 1
    jne label_52
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_52
L220:
# jump_f
    jmp label_55
# label_L
label_51:
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+8]
    mov rdi, qword ptr [rbx+8]
    cmp rdi, rsi
    short je L221
    rex test dil, 1
    jne label_52
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_52
L221:
# recv_marker_clear_S
    mov rsi, qword ptr [rsp+8]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435276112
    mov rsp, rbp
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
    mov r10, qword ptr [rsp+24]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 32
# line_I
# i_call_f
.db 0x90
    call display_log/1
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L124
    ret
# label_L
label_52:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    jmp label_50
# aligned_label_Lt
    align 4
label_53:
# wait_timeout_locked_sf
    mov esi, 4815
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rdx, qword ptr [L223]
    call 94068434776064
    mov rsp, rbp
    cmp rax, 1
    short je L222
    short jl L223
    lea rsi, qword ptr [label_53]
    xor ecx, ecx
    push rsi
    jmp L224
L222:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_50]
    call 94068434775632
    mov rsp, rbp
    jmp L129
    align 4
L223:
# timeout
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068434776496
    mov rsp, rbp
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 23435
# init_yregs_I
    mov eax, 59
    mov qword ptr [rsp], rax
    mov qword ptr [rsp+16], rax
# line_I
# call_light_bif_be
    align 4
L225:
L226:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092368
    lea rdx, qword ptr [L225]
# BIF: erlang:exit/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# recv_marker_use_S
    mov rsi, qword ptr [rsp+8]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274800
    mov rsp, rbp
# aligned_label_Lt
    align 4
label_54:
# i_loop_rec_f
    align 4
L227:
    lea rdi, qword ptr [L227]
    lea rsi, qword ptr [label_58]
    call 139636653425768
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_57
    cmp dword ptr [rsi-2], 320
    jne label_57
    cmp qword ptr [rsi+6], 1355
    jne label_57
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+38]
    mov qword ptr [rbx], r11
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r11, 523
    jne label_56
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+8]
# simplified fetching of BEAM register
    mov rdi, r10
    cmp rdi, rsi
    short je L228
    rex test dil, 1
    jne label_57
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_57
L228:
# label_L
label_55:
# recv_marker_clear_S
    mov rsi, qword ptr [rsp+8]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435276112
    mov rsp, rbp
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
    mov r10, qword ptr [rsp+32]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 40
# return
    dec r14d
    jl L124
    ret
# label_L
label_56:
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+8]
    mov rdi, qword ptr [rbx+8]
    cmp rdi, rsi
    short je L229
    rex test dil, 1
    jne label_57
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_57
L229:
# recv_marker_clear_S
    mov rsi, qword ptr [rsp+8]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435276112
    mov rsp, rbp
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
    mov r10, qword ptr [rsp+24]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 40
# line_I
# i_call_f
    call display_log/1
# i_move_sd
    mov qword ptr [rbx], 400843
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# label_L
label_57:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    jmp label_54
# aligned_label_Lt
    align 4
label_58:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_54]
    call 94068434775632
    mov rsp, rbp
    jmp L129
# i_func_label_L
    align 8
label_59:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:display_log/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x56, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
display_log/1:
# i_breakpoint_trampoline
    short jmp L230
.db 0x90
    call L110
L230:
# i_test_yield
    lea rdx, qword ptr [display_log/1+24]
    dec r14d
    long jle L111
    align 4
# i_get_map_elements_fsI
.section .rodata {#1}
L233:
    align 8
.db 0xCB, 0x68, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x13, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0xA6, 0x11, 0x9D, 0x24, 0xB9, 0xD8, 0xB9, 0x8D
    align 8
.db 0x0B, 0x07, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x23, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x2C, 0x1A, 0x52, 0xD9, 0x89, 0xAE, 0x4F, 0x8D
.section .text {#0}
    mov rdi, qword ptr [rbx]
# simplified multi-element lookup
    mov eax, dword ptr [rdi-2]
    and al, 252
    cmp al, 44
    jne L231
    mov eax, dword ptr [rdi+6]
    mov rsi, qword ptr [rdi+14]
L234:
    dec eax
    short jl label_59
    cmp qword ptr [rsi+rax*8+6], 132875
    short jne L234
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+16], rdx
L235:
    dec eax
    short jl label_59
    cmp qword ptr [rsi+rax*8+6], 26827
    short jne L235
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+8], rdx
    short jmp L232
L231:
    mov ecx, 2
    lea r8, qword ptr [L233]
    mov rdx, rsp
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rbx
    call 94068434772192
    mov rsp, rbp
    test rax, rax
    je label_59
L232:
# is_map_fs
    mov rdi, qword ptr [rbx+8]
    rex test dil, 1
    jne label_59
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_59
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 52363
    mov rdx, -5706953854613786758
    call L112
    jne label_59
    mov qword ptr [rbx+24], rax
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx+8]
    mov esi, 15691
    mov rdx, -8521787742890970463
    call L112
    jne label_61
    mov qword ptr [rbx], rax
# is_map_fs
# simplified fetching of BEAM register
    mov rdi, rax
    rex test dil, 1
    jne label_61
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_61
# i_get_map_element_hash_fScWS
    mov rdi, qword ptr [rbx]
    mov esi, 45643
    mov rdx, -6294190680789208313
    call L112
    jne label_61
    mov qword ptr [rbx], rax
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx+16]
    rex test sil, 1
    jne label_61
    cmp dword ptr [rsi-2], 128
    jne label_61
    cmp qword ptr [rsi+6], 145675
    jne label_61
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L236
    mov ecx, 4
    call 139636653423200
L236:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+16]
    mov qword ptr [rsp+8], r11
# i_move_sd
    mov rdx, qword ptr [rbx+24]
    mov qword ptr [rbx], rdx
# line_I
# i_call_f
    call display_date/1
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 16
    jmp display_report/2
# label_L
label_61:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L237
    mov ecx, 4
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L237:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# line_I
# i_call_f
    call display_date/1
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 8
    jmp display/1
# i_func_label_L
    align 8
label_62:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:display_date/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x56, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
display_date/1:
# i_breakpoint_trampoline
    short jmp L238
.db 0x90
    call L110
L238:
# i_test_yield
    lea rdx, qword ptr [display_date/1+24]
    dec r14d
    long jle L111
    align 4
# is_integer_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 15
    short je L239
    test al, 1
    short jne label_62
    mov eax, dword ptr [rdi-2]
    and al, 59
    cmp al, 8
    short jne label_62
L239:
# line_I
# i_rem_div_ssjdd
# simplified fetching of BEAM register
    mov rax, rdi
# simplified test for small dividend since it is an integer
    test al, 1
    short je L240
# divide with inlined code
    mov r9, 1000000
    sar rax, 4
    cqo
    idiv r9
    sal rax, 4
    sal rdx, 4
    or rax, 15
    or rdx, 15
    short jmp L241
L240:
    mov ecx, 16000015
    mov rdi, rax
    mov r8, 94068441273840
    call L242
L241:
    mov qword ptr [rbx+8], rdx
    mov qword ptr [rbx], rax
# allocate_tt
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L243
    mov ecx, 2
.db 0x90
    call 139636653423200
L243:
    sub rsp, 48
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    mov ecx, 5
    rep stos qword ptr [rdi], rax
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+40], r10
# line_I
# call_light_bif_be
    align 4
L244:
L245:
    long mov rcx, 9223372036854775807
    mov rax, 94068436108336
    lea rdx, qword ptr [L244]
# BIF: erlang:posixtime_to_universaltime/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# line_I
# call_light_bif_be
    align 4
L246:
L247:
    long mov rcx, 9223372036854775807
    mov rax, 94068436107184
    lea rdx, qword ptr [L246]
# BIF: erlang:universaltime_to_localtime/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_64
    cmp dword ptr [rsi-2], 128
    jne label_64
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rsp+32], r10
# i_is_tuple_of_arity_fsA
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_64
    cmp dword ptr [rsi-2], 192
    jne label_64
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rsp+24], r11
# i_is_tuple_of_arity_fsA
# simplified fetching of BEAM register
    mov rsi, r11
    rex test sil, 1
    jne label_64
    cmp dword ptr [rsi-2], 192
    jne label_64
# load_tuple_ptr_s
# simplified fetching of BEAM register
    mov rsi, r10
# i_get_tuple_element_sPS
    mov rdx, qword ptr [rsi+6]
    mov qword ptr [rbx], rdx
# line_I
# call_light_bif_be
    align 4
L248:
L249:
    long mov rcx, 9223372036854775807
    mov rax, 94068436125680
    lea rdx, qword ptr [L248]
# BIF: erlang:integer_to_list/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+32]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+16], r11
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 47
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call pad/2
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+32]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+32], r11
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 47
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call pad/2
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+24]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+8], r11
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 47
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call pad/2
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+24]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp], r11
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 47
# line_I
# i_call_f
    call pad/2
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+24]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+24], r11
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 47
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call pad/2
# swap_dd
    mov rdi, qword ptr [rsp+40]
    mov rsi, qword ptr [rbx]
    mov qword ptr [rbx], rdi
    mov qword ptr [rsp+40], rsi
# i_move_sd
    mov qword ptr [rbx+8], 111
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call pad/2
# i_move_sd
L250:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# call_light_bif_be
    align 4
L251:
L252:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L251]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L253
    mov ecx, 1
    call 139636653423200
L253:
# put_cons_ss
    mov qword ptr [r15], 751
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rsp+40]
    mov qword ptr [rbx], r10
# init_yregs_I
    mov qword ptr [rsp+40], 59
# line_I
# call_light_bif_be
    align 4
L254:
L255:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L254]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L256
    mov ecx, 1
    call 139636653423200
L256:
# put_cons_ss
    mov qword ptr [r15], 943
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rsp+24]
    mov qword ptr [rbx], r10
# init_yregs_I
    mov qword ptr [rsp+24], 59
# line_I
# call_light_bif_be
    align 4
L257:
L258:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L257]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L259
    mov ecx, 1
    call 139636653423200
L259:
# put_cons_ss
    mov qword ptr [r15], 943
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 8
# line_I
# call_light_bif_be
    align 4
L260:
L261:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L260]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L262
    mov ecx, 1
    call 139636653423200
L262:
# put_cons_ss
    mov qword ptr [r15], 527
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 8
# line_I
# call_light_bif_be
    align 4
L263:
L264:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L263]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L265
    mov ecx, 1
    call 139636653423200
L265:
# put_cons_ss
    mov qword ptr [r15], 735
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# init_yregs_I
    mov qword ptr [rsp+16], 59
# line_I
# call_light_bif_be
    align 4
L266:
L267:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L266]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L268
    mov ecx, 1
    call 139636653423200
L268:
# put_cons_ss
    mov qword ptr [r15], 735
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 32
# line_I
# call_light_bif_be
    align 4
L269:
L270:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L269]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 85323
# line_I
# call_light_bif_be
    align 4
L271:
L272:
    long mov rcx, 9223372036854775807
    mov rax, 94068435962656
    lea rdx, qword ptr [L271]
# BIF: erlang:display_string/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# label_L
label_64:
# line_I
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L131
# i_func_label_L
    nop
    align 8
label_65:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:pad/2
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x57, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
pad/2:
# i_breakpoint_trampoline
    short jmp L273
.db 0x90
    call L110
L273:
# i_test_yield
    lea rdx, qword ptr [pad/2+24]
    dec r14d
    long jle L111
    align 4
# is_integer_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 15
    short je L274
    test al, 1
    jne label_67
    mov eax, dword ptr [rdi-2]
    and al, 59
    cmp al, 8
    jne label_67
L274:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L275
    mov ecx, 2
    call 139636653423200
L275:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# line_I
# call_light_bif_be
    align 4
L276:
L277:
    long mov rcx, 9223372036854775807
    mov rax, 94068436125680
    lea rdx, qword ptr [L276]
# BIF: erlang:integer_to_list/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_call_last_ft
    add rsp, 8
    jmp pad/2
# label_L
label_67:
# i_length_setup_jts
    mov rdi, qword ptr [rbx]
    mov qword ptr [rbx+16], rdi
    mov qword ptr [rbx+24], 15
# i_length_jtd
    align 4
L278:
    mov esi, 2
    lea rdx, qword ptr [L278]
    call L279
    je label_68
    mov qword ptr [rbx+16], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    mov rdi, qword ptr [rbx+8]
    cmp rax, rdi
    jne label_68
# return
    dec r14d
    jl L124
    ret
# label_L
label_68:
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L280
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L280:
# put_cons_ss
    mov qword ptr [r15], 783
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# i_call_only_f
    jmp pad/2
# i_func_label_L
    align 8
label_69:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:display/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0xBE, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
display/1:
# i_breakpoint_trampoline
    short jmp L281
.db 0x90
    call L110
L281:
# i_test_yield
    lea rdx, qword ptr [display/1+24]
    dec r14d
    long jle L111
    align 4
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    short jne label_69
    cmp dword ptr [rsi-2], 128
    short jne label_69
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 62923
    je label_71
    cmp rsi, 145675
    je label_73
    jmp label_75
# label_L
label_71:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L282
    mov ecx, 3
.db 0x90
    call 139636653423200
L282:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# catch_yf
    inc qword ptr [r13+256]
L283:
    mov eax, 2147483647
    mov qword ptr [rsp+8], rax
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L284:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# try_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+8], 59
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_trim_t
    add rsp, 16
# i_move_sd
    mov qword ptr [rbx], 85323
# line_I
# call_light_bif_be
    align 4
L285:
L286:
    long mov rcx, 9223372036854775807
    mov rax, 94068435962656
    lea rdx, qword ptr [L285]
# BIF: erlang:display_string/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
L287:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 85323
# line_I
# call_light_bif_be
    align 4
L288:
L289:
    long mov rcx, 9223372036854775807
    mov rax, 94068435962656
    lea rdx, qword ptr [L288]
# BIF: erlang:display_string/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# label_L
label_72:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L290:
L291:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109200
    lea rdx, qword ptr [L290]
# BIF: erlang:display/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L124
    ret
# label_L
label_73:
# is_map_fs
    mov rdi, qword ptr [rbx+16]
    rex test dil, 1
    jne label_74
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_74
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L292
    mov ecx, 3
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L292:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L293:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_call_last_ft
    jmp display_report/1
# label_L
label_74:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp display_report/1
# label_L
label_75:
# is_list_fs
    mov rax, qword ptr [rbx+8]
    cmp rax, 59
    short je L294
    test al, 2
    jne label_69
L294:
# is_list_fs
    mov rax, qword ptr [rbx+16]
    cmp rax, 59
    short je L295
    test al, 2
    jne label_69
L295:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L296
    mov ecx, 3
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L296:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rbx], r11
# i_move_sd
L297:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# line_I
# call_light_bif_be
    align 4
L298:
L299:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L298]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 85323
# call_light_bif_be
    align 4
L300:
L301:
    long mov rcx, 9223372036854775807
    mov rax, 94068435962656
    lea rdx, qword ptr [L300]
# BIF: erlang:display_string/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 8
# line_I
# i_call_f
    call '-display/1-lc$^0/1-0-'/1
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# i_func_label_L
    align 8
label_76:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:display_report/2
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x57, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
display_report/2:
# i_breakpoint_trampoline
    short jmp L302
.db 0x90
    call L110
L302:
# i_test_yield
    lea rdx, qword ptr [display_report/2+24]
    dec r14d
    long jle L111
    align 4
# is_atom_fs
    mov rax, qword ptr [rbx]
    and al, 63
    cmp al, 11
    jne label_78
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L303
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L303:
    sub rsp, 16
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+8], r10
# line_I
# call_light_bif_be
    align 4
L304:
L305:
    long mov rcx, 9223372036854775807
    mov rax, 94068436101616
    lea rdx, qword ptr [L304]
# BIF: erlang:atom_to_list/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# line_I
# i_length_setup_jts
    mov rdi, qword ptr [rbx]
    mov qword ptr [rbx+8], rdi
    mov qword ptr [rbx+16], 15
    mov rdi, qword ptr [rbx]
    mov qword ptr [rbx+24], rdi
# i_length_jtd
    align 4
L306:
    mov esi, 1
    lea rdx, qword ptr [L306]
    call L307
    mov qword ptr [rbx+8], rax
# line_I
# i_minus_ssjd
# subtract without overflow check
    mov eax, 335
    mov rsi, qword ptr [rbx+8]
    and rsi, -16
    sub rax, rsi
    mov qword ptr [rbx+8], rax
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], rax
# i_move_sd
    mov qword ptr [rbx+8], 527
# i_call_ext_e
L308:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_trim_t
    add rsp, 8
# line_I
# call_light_bif_be
    align 4
L309:
L310:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L309]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 85323
# call_light_bif_be
    align 4
L311:
L312:
    long mov rcx, 9223372036854775807
    mov rax, 94068435962656
    lea rdx, qword ptr [L311]
# BIF: erlang:display_string/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 8
    jmp display_report/1
# label_L
label_78:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L313
    mov ecx, 2
    call 139636653423200
L313:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15+8], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L314
    mov ecx, 1
    call 139636653423200
L314:
# call_light_bif_be
    align 4
L315:
L316:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109200
    lea rdx, qword ptr [L315]
# BIF: erlang:display/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# i_func_label_L
    align 8
label_79:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:display_report/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x57, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
display_report/1:
# i_breakpoint_trampoline
    short jmp L317
.db 0x90
    call L110
L317:
# i_test_yield
    lea rdx, qword ptr [display_report/1+24]
    dec r14d
    long jle L111
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_83
# (moving head and tail together)
    vmovups xmm0, xmmword ptr [rax-1]
    vmovups xmmword ptr [rbx+8], xmm0
# is_eq_exact_fss
# optimized equality test with [[]]
    mov rax, qword ptr [rbx+16]
    test al, 2
    jne label_81
    cmp qword ptr [rax-1], 59
    jne label_81
    cmp qword ptr [rax+7], 59
    jne label_81
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_call_only_f
    short jmp display_report/1
# label_L
label_81:
# allocate_heap_tIt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L318
    mov ecx, 1
    call 139636653423200
L318:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
L319:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx+8], r10
# line_I
# i_call_ext_e
L320:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_82
# i_move_sd
L321:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 85323
# line_I
# call_light_bif_be
    align 4
L322:
L323:
    long mov rcx, 9223372036854775807
    mov rax, 94068435962656
    lea rdx, qword ptr [L322]
# BIF: erlang:display_string/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L324
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L324:
# i_move_sd
L325:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# line_I
# i_call_ext_last_et
    add rsp, 8
L326:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_82:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L327:
L328:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109200
    lea rdx, qword ptr [L327]
# BIF: erlang:display/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L124
    ret
# label_L
label_83:
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_84
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_84
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 145675
    mov rdx, 6704235728667070833
    call L112
    jne label_84
    mov qword ptr [rbx+8], rax
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], rax
# i_call_only_f
    jmp display_report/1
# label_L
label_84:
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L329
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L329:
# call_light_bif_be
    align 4
L330:
L331:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109200
    lea rdx, qword ptr [L330]
# BIF: erlang:display/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# i_func_label_L
    align 8
label_85:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:module_info/0
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L332
.db 0x90
    call L110
L332:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L111
    align 4
# i_move_sd
    mov qword ptr [rbx], 204747
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L333
    mov ecx, 1
.db 0x90
    call 139636653423200
L333:
# call_light_bif_be
    align 4
L334:
L335:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L334]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# i_func_label_L
    align 8
label_87:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:module_info/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L336
.db 0x90
    call L110
L336:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L111
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 204747
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L337
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L337:
# call_light_bif_be
    align 4
L338:
L339:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L338]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# i_func_label_L
    align 8
label_89:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:'-display_report/1-fun-1-'/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x57, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-display_report/1-fun-1-'/1:
# i_breakpoint_trampoline
    short jmp L340
.db 0x90
    call L110
L340:
# i_test_yield
    lea rdx, qword ptr ['-display_report/1-fun-1-'/1+24]
    dec r14d
    long jle L111
    align 4
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    short jne label_89
    cmp dword ptr [rsi-2], 128
    short jne label_89
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L341
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L341:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# load_tuple_ptr_s
# simplified fetching of BEAM register
    mov rsi, r10
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+6]
    mov qword ptr [rbx], r11
# line_I
# call_light_bif_be
    align 4
L342:
L343:
    long mov rcx, 9223372036854775807
    mov rax, 94068436101616
    lea rdx, qword ptr [L342]
# BIF: erlang:atom_to_list/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
L344:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# call_light_bif_be
    align 4
L345:
L346:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L345]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+96]
    cmp rdx, rsp
    short jbe L347
    mov ecx, 1
    call 139636653423200
L347:
# put_cons_ss
    mov qword ptr [r15], 527
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 527
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov qword ptr [r15+32], 527
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# append_cons_Is
    mov qword ptr [r15], 527
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov qword ptr [rbx], 85323
# line_I
# call_light_bif_be
    align 4
L348:
L349:
    long mov rcx, 9223372036854775807
    mov rax, 94068435962656
    lea rdx, qword ptr [L348]
# BIF: erlang:display_string/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L350:
L351:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109200
    lea rdx, qword ptr [L350]
# BIF: erlang:display/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L124
    ret
# i_func_label_L
    align 8
label_91:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:'-display_report/1-fun-0-'/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x57, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-display_report/1-fun-0-'/1:
# i_breakpoint_trampoline
    short jmp L352
.db 0x90
    call L110
L352:
# i_test_yield
    lea rdx, qword ptr ['-display_report/1-fun-0-'/1+24]
    dec r14d
    long jle L111
    align 4
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_93
    cmp dword ptr [rsi-2], 128
    jne label_93
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# nofail_bif1_sbd
    lea rsi, qword ptr [rbx]
# UBIF: is_atom/1
    mov rcx, 94068435878064
    call L353
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L124
    ret
# label_L
label_93:
# i_move_sd
    mov qword ptr [rbx], 11
# return
    dec r14d
    jl L124
    ret
# i_func_label_L
    align 8
label_94:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:'-display/1-lc$^0/1-0-'/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x58, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-display/1-lc$^0/1-0-'/1:
# i_breakpoint_trampoline
    short jmp L354
.db 0x90
    call L110
L354:
# i_test_yield
    lea rdx, qword ptr ['-display/1-lc$^0/1-0-'/1+24]
    dec r14d
    long jle L111
    align 4
# is_nonempty_list_fS
    test byte ptr [rbx], 2
    jne label_96
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L355
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L355:
    sub rsp, 16
# get_list_Sdd
    mov rdi, qword ptr [rbx]
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rdi-1], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
L356:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 85323
# line_I
# call_light_bif_be
    align 4
L357:
L358:
    long mov rcx, 9223372036854775807
    mov rax, 94068435962656
    lea rdx, qword ptr [L357]
# BIF: erlang:display_string/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rsp+8], r11
# i_trim_t
    add rsp, 8
# line_I
# call_light_bif_be
    align 4
L359:
L360:
    long mov rcx, 9223372036854775807
    mov rax, 94068436109200
    lea rdx, qword ptr [L359]
# BIF: erlang:display/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 8
    jmp '-display/1-lc$^0/1-0-'/1
# label_L
label_96:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_97
# return
    dec r14d
    jl L124
    ret
# label_L
label_97:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L361
    mov ecx, 1
.db 0x90
    call 139636653423200
L361:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 94667
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L362
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L362:
# call_light_bif_be
    align 4
L363:
L364:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L363]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_98:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:'-log_internal/2-fun-0-'/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x58, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-log_internal/2-fun-0-'/1:
# i_breakpoint_trampoline
    short jmp L365
.db 0x90
    call L110
L365:
# i_test_yield
    lea rdx, qword ptr ['-log_internal/2-fun-0-'/1+24]
    dec r14d
    long jle L111
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L366
    mov ecx, 1
    call 139636653423200
L366:
# i_move_sd
L367:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# line_I
# i_call_ext_e
L368:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# line_I
# i_call_ext_e
L369:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_call_ext_e
L370:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 85323
# call_light_bif_be
    align 4
L371:
L372:
    long mov rcx, 9223372036854775807
    mov rax, 94068435962656
    lea rdx, qword ptr [L371]
# BIF: erlang:display_string/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L124
    ret
# i_lambda_trampoline_FfWW
L106:
    mov rax, [rcx+14]
    mov [rbx], rax
    jmp '-log_internal/2-fun-0-'/1
# i_func_label_L
    align 8
label_100:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:'-replay_buffer/1-F/1-0-'/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x58, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-replay_buffer/1-F/1-0-'/1:
# i_breakpoint_trampoline
    short jmp L373
.db 0x90
    call L110
L373:
# i_test_yield
    lea rdx, qword ptr ['-replay_buffer/1-F/1-0-'/1+24]
    dec r14d
    long jle L111
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    short jne label_100
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    short jne label_100
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 132875
    mov rdx, -8264194884121781716
    call L112
    short jne label_100
    mov qword ptr [rbx+8], rax
# i_is_tuple_of_arity_fsA
# simplified fetching of BEAM register
    mov rsi, rax
    rex test sil, 1
    jne label_103
    cmp dword ptr [rsi-2], 128
    jne label_103
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r10
    cmp rsi, 62923
    je label_102
    cmp rsi, 145675
    je label_102
    jmp label_103
# label_L
label_102:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# line_I
# update_map_exact_sjdtI
    mov esi, 132875
# simplified fetching of BEAM register
    mov rdx, r10
    mov rcx, qword ptr [rbx]
.db 0x0F, 0x1F, 0x00
    call 139636653428392
    mov qword ptr [rbx], rax
# i_call_only_f
    jmp '-replay_buffer/1-F/1-0-'/1
# label_L
label_103:
# i_get_map_elements_fsI
.section .rodata {#1}
L376:
    align 8
.db 0xCB, 0x68, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x33, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0xA6, 0x11, 0x9D, 0x24, 0xB9, 0xD8, 0xB9, 0x8D
    align 8
.db 0x4B, 0x18, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x23, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x87, 0x24, 0xCE, 0x4E, 0x39, 0x36, 0x3B, 0xB2
.section .text {#0}
    mov rdi, qword ptr [rbx]
# simplified multi-element lookup
    mov eax, dword ptr [rdi-2]
    and al, 252
    cmp al, 44
    jne L374
    mov eax, dword ptr [rdi+6]
    mov rsi, qword ptr [rdi+14]
L377:
    dec eax
    jl label_100
    cmp qword ptr [rsi+rax*8+6], 137291
    short jne L377
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+16], rdx
L378:
    dec eax
    jl label_100
    cmp qword ptr [rsi+rax*8+6], 26827
    short jne L378
    mov rdx, qword ptr [rdi+rax*8+22]
    mov qword ptr [rbx+24], rdx
    short jmp L375
L374:
    mov ecx, 2
    lea r8, qword ptr [L376]
    mov rdx, rsp
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rbx
    call 94068434772192
    mov rsp, rbp
    test rax, rax
    je label_100
L375:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx+16], r11
# line_I
# i_call_ext_only_e
L379:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_104:
# func_line_I
# i_func_info_IaaI
# logger_simple_h:'-adding_handler/1-fun-0-'/1
    call L108
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x58, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-adding_handler/1-fun-0-'/1:
# i_breakpoint_trampoline
    short jmp L380
.db 0x90
    call L110
L380:
# i_test_yield
    lea rdx, qword ptr ['-adding_handler/1-fun-0-'/1+24]
    dec r14d
    long jle L111
    align 4
# i_call_only_f
    jmp init/1
# i_lambda_trampoline_FfWW
L105:
    mov rax, [rcx+14]
    mov [rbx], rax
    short jmp '-adding_handler/1-fun-0-'/1
# int_code_end
L381:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L307:
    jmp 139636653425480
L353:
    jmp 139636653424264
L110:
    jmp 139636653424496
L186:
    jmp 139636653427096
L187:
    jmp 139636653428344
L124:
    jmp 139636653422960
L108:
    jmp 139636653424856
L129:
    jmp 139636653427727
L131:
    jmp 139636653427776
L111:
    jmp 139636653426040
L190:
    jmp 139636653426736
L224:
    jmp 139636653427784
L279:
    jmp 139636653425376
L112:
    jmp 139636653425144
L242:
    jmp 139636653426072
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x02, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0xE3, 0xBF, 0x3B, 0xF1, 0x35, 0x2A, 0xA5, 0x98, 0xE9, 0xE7, 0x07, 0x03, 0x91, 0x5A, 0xC2, 0x52, 0x6A, 0x68, 0x02, 0x77, 0x09, 0x62, 0x65, 0x68, 0x61, 0x76, 0x69, 0x6F, 0x75, 0x72, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x77, 0x0E, 0x6C, 0x6F, 0x67, 0x67, 0x65, 0x72, 0x5F, 0x68, 0x61, 0x6E, 0x64, 0x6C, 0x65, 0x72, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x31, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x6C, 0x6F, 0x67, 0x67, 0x65, 0x72, 0x5F, 0x73, 0x69, 0x6D, 0x70, 0x6C, 0x65, 0x5F, 0x68, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0x52, 0xC2, 0x5A, 0x91, 0x03, 0x07, 0xE7, 0xE9, 0x98, 0xA5, 0x2A, 0x35, 0xF1, 0x3B, 0xBF, 0xE3
.section .text {#0}
