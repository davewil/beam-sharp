    align 8
L108:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# file_server:format_error/1
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x68, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
format_error/1:
# i_breakpoint_trampoline
    short jmp L110
.db 0x90
    call L111
L110:
# i_test_yield
    lea rdx, qword ptr [format_error/1+24]
    dec r14d
    long jle L112
    align 4
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_4
    cmp dword ptr [rsi-2], 192
    jne label_4
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+14], 1
    vmovups xmmword ptr [rbx], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 204235
    jne label_3
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L113
    mov ecx, 1
.db 0x90
    call 139636653423200
L113:
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
L114:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_call_ext_only_e
L115:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_3:
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L116
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L116:
# i_move_sd
    mov qword ptr [rbx+16], 223307
# line_I
# apply_last_tt
    align 4
L118:
    mov edx, 1
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    lea rcx, qword ptr [L118]
    xor r8d, r8d
    call 94068435489472
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    short jne L117
    lea rsi, qword ptr [L118]
    mov rcx, 94068445024480
    push rsi
    jmp L119
L117:
    jmp qword ptr [rax+r12*8]
# label_L
label_4:
# line_I
# i_call_ext_only_e
L120:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_5:
# func_line_I
# i_func_info_IaaI
# file_server:start/0
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xA7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start/0:
# i_breakpoint_trampoline
    short jmp L121
.db 0x90
    call L111
L121:
# i_test_yield
    lea rdx, qword ptr [start/0+24]
    dec r14d
    long jle L112
    align 4
# i_move_sd
    mov qword ptr [rbx], 42827
# i_call_only_f
    jmp do_start/1
# i_func_label_L
    align 8
label_7:
# func_line_I
# i_func_info_IaaI
# file_server:start_link/0
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x42, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_link/0:
# i_breakpoint_trampoline
    short jmp L122
.db 0x90
    call L111
L122:
# i_test_yield
    lea rdx, qword ptr [start_link/0+24]
    dec r14d
    long jle L112
    align 4
# i_move_sd
    mov qword ptr [rbx], 213707
# i_call_only_f
    jmp do_start/1
# i_func_label_L
    align 8
label_9:
# func_line_I
# i_func_info_IaaI
# file_server:stop/0
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xA8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
stop/0:
# i_breakpoint_trampoline
    short jmp L123
.db 0x90
    call L111
L123:
# i_test_yield
    lea rdx, qword ptr [stop/0+24]
    dec r14d
    long jle L112
    align 4
# i_move_sd
    mov qword ptr [rbx+8], 43019
# i_move_sd
    mov qword ptr [rbx+16], 395
# i_move_sd
    mov qword ptr [rbx], 213963
# i_call_ext_only_e
L124:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_11:
# func_line_I
# i_func_info_IaaI
# file_server:init/1
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
init/1:
# i_breakpoint_trampoline
    short jmp L125
.db 0x90
    call L111
L125:
# i_test_yield
    lea rdx, qword ptr [init/1+24]
    dec r14d
    long jle L112
    align 4
# is_nil_fS
    cmp byte ptr [rbx], 59
    short jne label_11
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L126
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L126:
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx], 45387
# line_I
# call_light_bif_be
    align 4
L127:
L128:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L127]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
L129:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L130
    ret
# i_func_label_L
    align 8
label_13:
# func_line_I
# i_func_info_IaaI
# file_server:handle_call/3
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x59, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_call/3:
# i_breakpoint_trampoline
    short jmp L131
.db 0x90
    call L111
L131:
# i_test_yield
    lea rdx, qword ptr [handle_call/3+24]
    dec r14d
    long jle L112
    align 4
# i_is_tuple_fs
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_47
    test byte ptr [rsi-2], 63
    jne label_47
# i_select_tuple_arity_SfI
# skipped fetching of BEAM register
# skipped box test since argument is always boxed
    mov esi, dword ptr [rsi-2]
# simplified tuple test since the source is always a tuple when boxed
    cmp esi, 64
    je label_46
    cmp esi, 128
    je label_32
    cmp esi, 192
    je label_22
    cmp esi, 256
    je label_21
    cmp esi, 384
    je label_15
    jne label_50
# label_L
label_15:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+24], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 10635
    jne label_50
# allocate_heap_tIt
    lea rdx, qword ptr [r15+96]
    cmp rdx, rsp
    short jbe L132
    mov ecx, 3
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L132:
    sub rsp, 32
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp+16], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+24], r11
# load_tuple_ptr_s
# simplified fetching of BEAM register
    mov rsi, r11
# i_get_tuple_element_sPS
    mov rdx, qword ptr [rsi+22]
    mov qword ptr [rbx], rdx
# put_cons_ss
    mov qword ptr [r15], 6155
# simplified fetching of BEAM register
    mov rdi, rdx
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# append_cons_Is
    mov qword ptr [r15], 96651
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# load_tuple_ptr_s
# simplified fetching of BEAM register
    mov rsi, r11
# i_get_tuple_element_sPS
    mov rdx, qword ptr [rsi+14]
    mov qword ptr [rbx], rdx
# line_I
# i_call_ext_e
L133:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_52
    cmp dword ptr [rsi-2], 128
    jne label_52
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rsp+8], r11
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r10
    cmp rsi, 779
    je label_20
    cmp rsi, 32075
    je label_16
    jmp label_52
# label_L
label_16:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L134
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L134:
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+24]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+38]
    mov qword ptr [rbx], r10
# put_cons_ss
    mov qword ptr [r15], 6155
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# append_cons_Is
    mov qword ptr [r15], 96779
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+24]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L135:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_is_tuple_of_arity_fsA
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_51
    cmp dword ptr [rsi-2], 128
    jne label_51
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+6]
    mov qword ptr [rbx], r11
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r11
    cmp rsi, 779
    je label_18
    cmp rsi, 32075
    je label_17
    jmp label_51
# label_L
label_17:
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rsp], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+24]
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+46]
    mov qword ptr [rbx+16], r11
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx+8], r10
# init_yregs_I
    mov qword ptr [rsp+24], 59
# i_move_sd
    mov rdx, qword ptr [rsp+8]
    mov qword ptr [rbx], rdx
# line_I
# i_call_ext_e
L136:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+24], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# init_yregs_I
    mov qword ptr [rsp], 59
# line_I
# i_call_ext_e
L137:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# jump_f
    jmp label_19
# label_L
label_18:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rsp+24], r10
# label_L
label_19:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 16
# line_I
# i_call_ext_e
L138:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L139
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L139:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
# (moving and swapping two elements at once)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L130
    ret
# label_L
label_20:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L140
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L140:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 32
# return
    dec r14d
    jl L130
    ret
# label_L
label_21:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+24], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 120267
    jne label_50
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L141
    mov ecx, 3
    call 139636653423200
L141:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rbx+8], xmm0
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+30]
    mov qword ptr [rbx], r11
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rbx+8], xmm0
# swap_dd
# simplified fetching of BEAM register
    mov rdi, r11
    mov rsi, qword ptr [rbx+16]
    mov qword ptr [rbx+16], rdi
    mov qword ptr [rbx], rsi
# line_I
# i_call_ext_e
L142:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L143
    mov ecx, 1
    call 139636653423200
L143:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_22:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+24], xmm0
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+40], r10
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+24]
    cmp rsi, 32395
    je label_28
    cmp rsi, 60107
    je label_25
    cmp rsi, 90251
    je label_27
    cmp rsi, 119179
    je label_24
    cmp rsi, 119883
    je label_26
    cmp rsi, 120267
    je label_23
    cmp rsi, 121355
    je label_31
    cmp rsi, 121419
    je label_30
    jmp label_50
# label_L
label_23:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L144
    mov ecx, 6
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L144:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_e
L145:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L146
    mov ecx, 1
    call 139636653423200
L146:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_24:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L147
    mov ecx, 6
.db 0x90
    call 139636653423200
L147:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_e
L148:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L149
    mov ecx, 1
    call 139636653423200
L149:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_25:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L150
    mov ecx, 6
.db 0x90
    call 139636653423200
L150:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_e
L151:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L152
    mov ecx, 1
    call 139636653423200
L152:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_26:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L153
    mov ecx, 6
.db 0x90
    call 139636653423200
L153:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_e
L154:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L155
    mov ecx, 1
    call 139636653423200
L155:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_27:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L156
    mov ecx, 6
.db 0x90
    call 139636653423200
L156:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_e
L157:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L158
    mov ecx, 1
    call 139636653423200
L158:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_28:
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    jne label_29
    cmp dword ptr [rsi-2], 128
    jne label_29
# is_list_fs
    mov rax, qword ptr [rbx+40]
    cmp rax, 59
    short je L159
    test al, 2
    jne label_29
L159:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L160
    mov ecx, 6
    call 139636653423200
L160:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+6]
    mov qword ptr [rbx], r11
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx+8], xmm0
# line_I
# i_call_ext_e
L161:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L162
    mov ecx, 1
    call 139636653423200
L162:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_29:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L163
    mov ecx, 3
.db 0x90
    call 139636653423200
L163:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
L164:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L130
    ret
# label_L
label_30:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L165
    mov ecx, 6
.db 0x66, 0x90
    call 139636653423200
L165:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_e
L166:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L167
    mov ecx, 1
    call 139636653423200
L167:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_31:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L168
    mov ecx, 6
.db 0x90
    call 139636653423200
L168:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_e
L169:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L170
    mov ecx, 1
    call 139636653423200
L170:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_32:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+24], xmm0
# i_select_val_bins_sfI
    mov rsi, qword ptr [rbx+24]
# Binary search in table of 13 elements
# Subtree [0..12], pivot 6
    cmp rsi, 119499
    je label_41
    ja L171
# Linear search in [0..5], 6 elements
    cmp rsi, 59083
    je label_43
    cmp rsi, 88907
    je label_42
    cmp rsi, 90251
    je label_37
    cmp rsi, 119051
    je label_38
    cmp rsi, 119243
    je label_36
    cmp rsi, 119307
    je label_35
    jmp label_50
L171:
# Linear search in [7..12], 6 elements
    cmp rsi, 119563
    je label_40
    cmp rsi, 119883
    je label_34
    cmp rsi, 121163
    je label_33
    cmp rsi, 121227
    je label_39
    cmp rsi, 121291
    je label_44
    cmp rsi, 121483
    je label_45
    jmp label_50
# label_L
label_33:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L172
    mov ecx, 5
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L172:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L173:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L174
    mov ecx, 1
    call 139636653423200
L174:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_34:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L175
    mov ecx, 5
.db 0x90
    call 139636653423200
L175:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L176:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L177
    mov ecx, 1
    call 139636653423200
L177:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_35:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L178
    mov ecx, 5
.db 0x90
    call 139636653423200
L178:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L179:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L180
    mov ecx, 1
    call 139636653423200
L180:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_36:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L181
    mov ecx, 5
.db 0x90
    call 139636653423200
L181:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L182:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L183
    mov ecx, 1
    call 139636653423200
L183:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_37:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L184
    mov ecx, 5
.db 0x90
    call 139636653423200
L184:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L185:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L186
    mov ecx, 1
    call 139636653423200
L186:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_38:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L187
    mov ecx, 5
.db 0x90
    call 139636653423200
L187:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L188:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L189
    mov ecx, 1
    call 139636653423200
L189:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_39:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L190
    mov ecx, 5
.db 0x90
    call 139636653423200
L190:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L191:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L192
    mov ecx, 1
    call 139636653423200
L192:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_40:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L193
    mov ecx, 5
.db 0x90
    call 139636653423200
L193:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L194:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L195
    mov ecx, 1
    call 139636653423200
L195:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_41:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L196
    mov ecx, 5
.db 0x90
    call 139636653423200
L196:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L197:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L198
    mov ecx, 1
    call 139636653423200
L198:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_42:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L199
    mov ecx, 5
.db 0x90
    call 139636653423200
L199:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L200:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L201
    mov ecx, 1
    call 139636653423200
L201:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_43:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L202
    mov ecx, 5
.db 0x90
    call 139636653423200
L202:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L203:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L204
    mov ecx, 1
    call 139636653423200
L204:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_44:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L205
    mov ecx, 5
.db 0x90
    call 139636653423200
L205:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L206:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L207
    mov ecx, 1
    call 139636653423200
L207:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_45:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L208
    mov ecx, 5
.db 0x90
    call 139636653423200
L208:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+32]
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_e
L209:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L210
    mov ecx, 1
    call 139636653423200
L210:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_46:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+24], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 88907
    jne label_50
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L211
    mov ecx, 3
.db 0x90
    call 139636653423200
L211:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# line_I
# i_call_ext_e
L212:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L213
    mov ecx, 1
    call 139636653423200
L213:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_47:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 43019
    je label_48
    cmp rsi, 88907
    je label_49
    jmp label_50
# label_L
label_48:
# test_heap_It
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L214
    mov ecx, 3
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L214:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 256
# Move tuple data
    mov qword ptr [r15+8], 43019
    mov qword ptr [r15+16], 523
    mov qword ptr [r15+24], 222475
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+32], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 40
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L130
    ret
# label_L
label_49:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L215
    mov ecx, 3
    call 139636653423200
L215:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# line_I
# i_call_ext_e
L216:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L217
    mov ecx, 1
    call 139636653423200
L217:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 37323
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# label_L
label_50:
# allocate_heap_tIt
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L218
    mov ecx, 3
.db 0x90
    call 139636653423200
L218:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# put_cons_ss
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx+8], rsi
# i_move_sd
L219:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L220:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L221
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L221:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 219531
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
    jl L130
    ret
# label_L
label_51:
# line_I
# case_end_s
    mov rdi, qword ptr [rsp]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L222
# label_L
label_52:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L222
# i_func_label_L
    nop
    align 8
label_53:
# func_line_I
# i_func_info_IaaI
# file_server:handle_cast/2
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x5C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_cast/2:
# i_breakpoint_trampoline
    short jmp L223
.db 0x90
    call L111
L223:
# i_test_yield
    lea rdx, qword ptr [handle_cast/2+24]
    dec r14d
    long jle L112
    align 4
# allocate_heap_tIt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L224
    mov ecx, 2
    call 139636653423200
L224:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
L225:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L226:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L227
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L227:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 219531
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
    jl L130
    ret
# i_func_label_L
    align 8
label_55:
# func_line_I
# i_func_info_IaaI
# file_server:handle_info/2
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x5D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_info/2:
# i_breakpoint_trampoline
    short jmp L228
.db 0x90
    call L111
L228:
# i_test_yield
    lea rdx, qword ptr [handle_info/2+24]
    dec r14d
    long jle L112
    align 4
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_57
    cmp dword ptr [rsi-2], 192
    jne label_57
    cmp qword ptr [rsi+6], 1483
    jne label_57
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+16], r10
# is_pid_fs
# simplified fetching of BEAM register
    mov rdi, r10
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L229
    test al, 1
    jne label_57
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_57
L229:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L230
    mov ecx, 2
    call 139636653423200
L230:
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
    jl L130
    ret
# label_L
label_57:
# allocate_heap_tIt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L231
    mov ecx, 2
    call 139636653423200
L231:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
L232:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L233:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L234
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L234:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 219531
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
    jl L130
    ret
# i_func_label_L
    align 8
label_58:
# func_line_I
# i_func_info_IaaI
# file_server:terminate/2
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x53, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
terminate/2:
# i_breakpoint_trampoline
    short jmp L235
.db 0x90
    call L111
L235:
# i_test_yield
    lea rdx, qword ptr [terminate/2+24]
    dec r14d
    long jle L112
    align 4
# i_move_sd
    mov qword ptr [rbx], 32075
# return
    dec r14d
    jl L130
    ret
# i_func_label_L
    align 8
label_60:
# func_line_I
# i_func_info_IaaI
# file_server:code_change/3
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x61, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
code_change/3:
# i_breakpoint_trampoline
    short jmp L236
.db 0x90
    call L111
L236:
# i_test_yield
    lea rdx, qword ptr [code_change/3+24]
    dec r14d
    long jle L112
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L237
    mov ecx, 2
    call 139636653423200
L237:
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
    jl L130
    ret
# i_func_label_L
    align 8
label_62:
# func_line_I
# i_func_info_IaaI
# file_server:do_start/1
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x63, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_start/1:
# i_breakpoint_trampoline
    short jmp L238
.db 0x90
    call L111
L238:
# i_test_yield
    lea rdx, qword ptr [do_start/1+24]
    dec r14d
    long jle L112
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L239
    mov ecx, 1
    call 139636653423200
L239:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov qword ptr [rbx], 180875
# line_I
# i_call_ext_e
L240:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_64
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_64
    cmp edi, 128
    jne label_65
    cmp qword ptr [rsi+6], 32075
    jne label_65
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# is_nonempty_list_get_list_fSdd
# simplified fetching of BEAM register
    mov rax, r10
    test al, 2
    jne label_65
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rax-1], 1
    vmovups xmmword ptr [rbx+8], xmm0
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx+16]
    test al, 2
    jne label_65
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rax-1], 1
    vmovups xmmword ptr [rbx+16], xmm0
# is_nil_fS
    cmp byte ptr [rbx+16], 59
    jne label_65
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    jne label_65
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L241:
L242:
    long mov rcx, 9223372036854775807
    mov rax, 94068436101856
    lea rdx, qword ptr [L241]
# BIF: erlang:list_to_atom/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+16], 213963
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp do_start/3
# label_L
label_64:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_65
# i_move_sd
    mov qword ptr [rbx+24], 59
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov qword ptr [rbx+32], 204491
# i_move_sd
    mov qword ptr [rbx+8], 204235
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+40], r10
# i_move_sd
L243:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# apply_last_tt
    add rsp, 8
    align 4
L245:
    mov edx, 4
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    lea rcx, qword ptr [L245]
    xor r8d, r8d
    call 94068435489472
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    short jne L244
    lea rsi, qword ptr [L245]
    mov rcx, 94068445024480
    push rsi
    jmp L119
L244:
    jmp qword ptr [rax+r12*8]
# label_L
label_65:
# test_heap_It
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L246
    mov ecx, 1
.db 0x90
    call 139636653423200
L246:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 81995
    mov qword ptr [r15+16], 180875
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
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
    add rsp, 8
# return
    dec r14d
    jl L130
    ret
# i_func_label_L
    align 8
label_66:
# func_line_I
# i_func_info_IaaI
# file_server:do_start/3
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x63, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_start/3:
# i_breakpoint_trampoline
    short jmp L247
.db 0x90
    call L111
L247:
# i_test_yield
    lea rdx, qword ptr [do_start/3+24]
    dec r14d
    long jle L112
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L248
    mov ecx, 2
    call 139636653423200
L248:
    sub rsp, 16
# init_yregs_I
    mov qword ptr [rsp+8], 59
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov qword ptr [rbx+16], 52811
# i_move_sd
L249:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+24], rdi
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rbx], r11
# i_move_sd
    mov qword ptr [rbx+8], 15435
# line_I
# i_call_ext_e
L250:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# is_pid_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L251
    test al, 1
    jne label_68
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_68
L251:
# jump_f
    jmp label_69
# label_L
label_68:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 907
    jne label_72
# label_L
label_69:
# catch_yf
    inc qword ptr [r13+256]
L252:
    mov eax, 2147483647
    mov qword ptr [rsp+8], rax
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+16], 213963
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# init_yregs_I
    mov qword ptr [rsp], 59
# line_I
# i_call_f
.db 0x66, 0x90
    call do_start_slave/3
# label_L
label_70:
# catch_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+8], 59
    cmp qword ptr [rbx], 0
    short jne L253
    call 139636653422576
L253:
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_71
    cmp dword ptr [rsi-2], 128
    jne label_71
    cmp qword ptr [rsi+6], 1483
    jne label_71
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L254
    mov ecx, 1
    call 139636653423200
L254:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
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
    jl L130
    ret
# label_L
label_71:
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L130
    ret
# label_L
label_72:
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L255
    mov ecx, 1
.db 0x90
    call 139636653423200
L255:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 273291
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
    jl L130
    ret
# i_func_label_L
    align 8
label_73:
# func_line_I
# i_func_info_IaaI
# file_server:do_start_slave/3
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x2B, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_start_slave/3:
# i_breakpoint_trampoline
    short jmp L256
.db 0x90
    call L111
L256:
# i_test_yield
    lea rdx, qword ptr [do_start_slave/3+24]
    dec r14d
    long jle L112
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 213707
    jne label_78
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L257
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L257:
    sub rsp, 24
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+16], r10
# self_d
    mov r11, qword ptr [r13]
    mov qword ptr [rsp+8], r11
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
# call_light_bif_be
    align 4
L258:
L259:
    long mov rcx, 9223372036854775807
    mov rax, 94068435960192
    lea rdx, qword ptr [L258]
# BIF: erlang:make_ref/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L260
    mov ecx, 1
    call 139636653423200
L260:
# i_make_fun3_FStt
L261:
    long mov rax, 9223372036854775807
# Create fun thing
    mov qword ptr [r15], 262164
    mov qword ptr [r15+8], rax
# Move fun environment
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], 213963
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+32], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+40], rdi
# Create boxed ptr
    lea rax, qword ptr [r15+2]
    add r15, 48
    mov qword ptr [rbx+8], rax
# recv_marker_bind_SS
    mov rsi, qword ptr [rsp]
# simplified fetching of BEAM register
    mov rdx, rdi
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435276384
    mov rsp, rbp
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L262:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# recv_marker_use_S
    mov rsi, qword ptr [rsp+16]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274800
    mov rsp, rbp
# aligned_label_Lt
    align 4
label_75:
# i_loop_rec_f
    align 4
L263:
    lea rdi, qword ptr [L263]
    lea rsi, qword ptr [label_77]
    call 139636653425768
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_76
    cmp dword ptr [rsi-2], 128
    jne label_76
    cmp qword ptr [rsi+6], 80907
    jne label_76
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+16]
# simplified fetching of BEAM register
    mov rdi, r10
    cmp rdi, rsi
    short je L264
    rex test dil, 1
    jne label_76
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_76
L264:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L265
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L265:
# recv_marker_clear_S
    mov rsi, qword ptr [rsp+16]
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
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 32075
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
    jl L130
    ret
# label_L
label_76:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    jmp label_75
# aligned_label_Lt
    align 4
label_77:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_75]
    call 94068434775632
    mov rsp, rbp
    jmp L266
# label_L
label_78:
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L267
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L267:
    sub rsp, 32
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+24], r10
# self_d
    mov r11, qword ptr [r13]
    mov qword ptr [rsp+16], r11
# call_light_bif_be
    align 4
L268:
L269:
    long mov rcx, 9223372036854775807
    mov rax, 94068435960192
    lea rdx, qword ptr [L268]
# BIF: erlang:make_ref/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L270
    mov ecx, 1
    call 139636653423200
L270:
# i_make_fun3_FStt
L271:
    long mov rax, 9223372036854775807
# Create fun thing
    mov qword ptr [r15], 262164
    mov qword ptr [r15+8], rax
# Move fun environment
    mov rdi, qword ptr [rsp+24]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], 213963
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+32], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+40], rdi
# Create boxed ptr
    lea rax, qword ptr [r15+2]
    add r15, 48
    mov qword ptr [rbx+8], rax
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp+24], rdi
# init_yregs_I
    mov qword ptr [rsp+16], 59
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], rax
# line_I
# i_call_ext_e
L272:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
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
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 35211
# line_I
# call_light_bif_be
    align 4
L273:
L274:
    long mov rcx, 9223372036854775807
    mov rax, 94068436086224
    lea rdx, qword ptr [L273]
# BIF: erlang:monitor/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
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
# aligned_label_Lt
    align 4
label_79:
# i_loop_rec_f
    align 4
L275:
    lea rdi, qword ptr [L275]
    lea rsi, qword ptr [label_83]
    call 139636653425768
# i_select_tuple_arity_SfI
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_82
    mov esi, dword ptr [rsi-2]
    rex test sil, 63
    jne label_82
    cmp esi, 128
    je label_81
    cmp esi, 320
    je label_80
    jne label_82
# label_L
label_80:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 1355
    jne label_82
# is_eq_exact_fss
    mov rsi, qword ptr [rsp]
    mov rdi, qword ptr [rbx+16]
    cmp rdi, rsi
    short je L276
    rex test dil, 1
    jne label_82
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_82
L276:
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
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+38]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L277:
L278:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091216
    lea rdx, qword ptr [L277]
# BIF: erlang:exit/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_81:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+6], 1
    vmovups xmmword ptr [rbx], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 80907
    jne label_82
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+24]
    mov rdi, qword ptr [rbx]
    cmp rdi, rsi
    short je L279
    rex test dil, 1
    jne label_82
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_82
L279:
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
L280:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rsp+16], xmm0
# i_trim_t
    add rsp, 16
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L281:
L282:
    long mov rcx, 9223372036854775807
    mov rax, 94068436085312
    lea rdx, qword ptr [L281]
# BIF: erlang:demonitor/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L283
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L283:
# recv_marker_clear_S
    mov rsi, qword ptr [rsp+8]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435276112
    mov rsp, rbp
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
    add rsp, 16
# return
    dec r14d
    jl L130
    ret
# label_L
label_82:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    jmp label_79
# aligned_label_Lt
    align 4
label_83:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_79]
    call 94068434775632
    mov rsp, rbp
    jmp L266
# i_func_label_L
    align 8
label_84:
# func_line_I
# i_func_info_IaaI
# file_server:relay_start/4
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x2C, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
relay_start/4:
# i_breakpoint_trampoline
    short jmp L284
.db 0x90
    call L111
L284:
# i_test_yield
    lea rdx, qword ptr [relay_start/4+24]
    dec r14d
    long jle L112
    align 4
# is_pid_fs
    mov rdi, qword ptr [rbx+16]
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L285
    test al, 1
    jne label_88
# skipped header test since we know it's a pid when boxed
L285:
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L286
    mov ecx, 3
    call 139636653423200
L286:
    sub rsp, 32
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# self_d
    mov r11, qword ptr [r13]
    mov qword ptr [rbx+8], r11
# catch_yf
    inc qword ptr [r13+256]
L287:
    mov eax, 2147483647
    mov qword ptr [rsp+24], rax
# i_move_sd
    mov qword ptr [rbx], 213963
# line_I
# call_light_bif_be
    align 4
L288:
L289:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094720
    lea rdx, qword ptr [L288]
# BIF: erlang:register/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_86:
# catch_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+24], 59
    cmp qword ptr [rbx], 0
    short jne L290
    call 139636653422576
L290:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_87
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 35211
# line_I
# call_light_bif_be
    align 4
L291:
L292:
    long mov rcx, 9223372036854775807
    mov rax, 94068436086224
    lea rdx, qword ptr [L291]
# BIF: erlang:monitor/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+24], r10
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx], 45387
# line_I
# call_light_bif_be
    align 4
L293:
L294:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L293]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L295
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L295:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 80907
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rsp+8], r11
# i_trim_t
    add rsp, 8
# i_move_sd
    mov rdx, qword ptr [rsp+8]
    mov qword ptr [rbx], rdx
# line_I
# send
    align 4
L296:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L296]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+16]
    mov qword ptr [rbx+16], r11
# i_move_sd
    mov rdx, qword ptr [rsp+8]
    mov qword ptr [rbx], rdx
# i_call_last_ft
    add rsp, 24
    jmp relay_loop/3
# label_L
label_87:
# i_trim_t
    add rsp, 32
# i_move_sd
    mov qword ptr [rbx], 213963
# line_I
# call_light_bif_be
    align 4
L297:
L298:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094864
    lea rdx, qword ptr [L297]
# BIF: erlang:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L299
    mov ecx, 1
    call 139636653423200
L299:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 222027
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# call_light_bif_be
    align 4
L300:
L301:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091216
    lea rdx, qword ptr [L300]
# BIF: erlang:exit/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_88:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L302
    mov ecx, 2
    call 139636653423200
L302:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx], 45387
# line_I
# call_light_bif_be
    align 4
L303:
L304:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L303]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L305
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L305:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 80907
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# line_I
# send
    align 4
L306:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L306]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# aligned_label_Lt
    align 4
label_89:
# i_loop_rec_f
    align 4
L307:
    lea rdi, qword ptr [L307]
    lea rsi, qword ptr [label_91]
    call 139636653425768
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_90
    cmp dword ptr [rsi-2], 192
    jne label_90
    cmp qword ptr [rsi+6], 1483
    jne label_90
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+8]
# simplified fetching of BEAM register
    mov rdi, r10
    cmp rdi, rsi
    short je L308
    mov eax, edi
    or eax, esi
    test al, 1
    jne label_90
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_90
L308:
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
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L309:
L310:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091216
    lea rdx, qword ptr [L309]
# BIF: erlang:exit/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_90:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    jmp label_89
# aligned_label_Lt
    align 4
label_91:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_89]
    call 94068434775632
    mov rsp, rbp
    jmp L266
# i_func_label_L
    align 8
label_92:
# func_line_I
# i_func_info_IaaI
# file_server:relay_loop/3
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x2C, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
relay_loop/3:
# i_breakpoint_trampoline
    short jmp L311
.db 0x90
    call L111
L311:
# i_test_yield
    lea rdx, qword ptr [relay_loop/3+24]
    dec r14d
    long jle L112
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L312
    mov ecx, 3
    call 139636653423200
L312:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# aligned_label_Lt
    align 4
label_94:
# i_loop_rec_f
    align 4
L313:
    lea rdi, qword ptr [L313]
    lea rsi, qword ptr [label_98]
    call 139636653425768
# i_select_tuple_arity_SfI
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_97
    mov esi, dword ptr [rsi-2]
    rex test sil, 63
    jne label_97
    cmp esi, 192
    je label_96
    cmp esi, 320
    je label_95
    jne label_97
# label_L
label_95:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 1355
    jne label_97
# is_eq_exact_fss
    mov rsi, qword ptr [rsp]
    mov rdi, qword ptr [rbx+16]
    cmp rdi, rsi
    short je L314
    rex test dil, 1
    jne label_97
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_97
L314:
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
    mov r10, qword ptr [rsi+38]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L315:
L316:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091216
    lea rdx, qword ptr [L315]
# BIF: erlang:exit/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_96:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 1483
    jne label_97
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+16]
    mov rdi, qword ptr [rbx+16]
    cmp rdi, rsi
    short je L317
    mov eax, edi
    or eax, esi
    test al, 1
    jne label_97
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_97
L317:
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
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L318:
L319:
    long mov rcx, 9223372036854775807
    mov rax, 94068436091216
    lea rdx, qword ptr [L318]
# BIF: erlang:exit/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_97:
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
# line_I
# send
    align 4
L320:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L320]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 24
    jmp relay_loop/3
# aligned_label_Lt
    align 4
label_98:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_94]
    call 94068434775632
    mov rsp, rbp
    jmp L266
# i_func_label_L
    align 8
label_99:
# func_line_I
# i_func_info_IaaI
# file_server:module_info/0
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L321
.db 0x90
    call L111
L321:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L112
    align 4
# i_move_sd
    mov qword ptr [rbx], 204235
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L322
    mov ecx, 1
.db 0x90
    call 139636653423200
L322:
# call_light_bif_be
    align 4
L323:
L324:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L323]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L130
    ret
# i_func_label_L
    align 8
label_101:
# func_line_I
# i_func_info_IaaI
# file_server:module_info/1
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L325
.db 0x90
    call L111
L325:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L112
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 204235
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L326
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L326:
# call_light_bif_be
    align 4
L327:
L328:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L327]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L130
    ret
# i_func_label_L
    align 8
label_103:
# func_line_I
# i_func_info_IaaI
# file_server:'-do_start_slave/3-fun-0-'/4
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x2C, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-do_start_slave/3-fun-0-'/4:
# i_breakpoint_trampoline
    short jmp L329
.db 0x90
    call L111
L329:
# i_test_yield
    lea rdx, qword ptr ['-do_start_slave/3-fun-0-'/4+24]
    dec r14d
    long jle L112
    align 4
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+24], 213963
# swap_dd
    mov rdi, qword ptr [rbx]
    mov rsi, qword ptr [rbx+16]
    mov qword ptr [rbx+16], rdi
    mov qword ptr [rbx], rsi
# i_call_only_f
    jmp relay_start/4
# i_lambda_trampoline_FfWW
L106:
    vmovups ymm0, [rcx+14]
    vmovups [rbx], ymm0
    short jmp '-do_start_slave/3-fun-0-'/4
# i_func_label_L
    align 8
label_105:
# func_line_I
# i_func_info_IaaI
# file_server:'-do_start_slave/3-fun-1-'/4
    call L109
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x1D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x2C, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-do_start_slave/3-fun-1-'/4:
# i_breakpoint_trampoline
    short jmp L330
.db 0x90
    call L111
L330:
# i_test_yield
    lea rdx, qword ptr ['-do_start_slave/3-fun-1-'/4+24]
    dec r14d
    long jle L112
    align 4
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+24], 213963
# swap_dd
    mov rdi, qword ptr [rbx]
    mov rsi, qword ptr [rbx+16]
    mov qword ptr [rbx+16], rdi
    mov qword ptr [rbx], rsi
# i_call_only_f
    jmp relay_start/4
# i_lambda_trampoline_FfWW
L107:
    vmovups ymm0, [rcx+14]
    vmovups [rbx], ymm0
    short jmp '-do_start_slave/3-fun-1-'/4
# int_code_end
L331:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L266:
    jmp 139636653427727
L222:
    jmp 139636653427776
L130:
    jmp 139636653422960
L119:
    jmp 139636653427784
L112:
    jmp 139636653426040
L111:
    jmp 139636653424496
L109:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x02, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0x86, 0x79, 0xB7, 0x11, 0xC1, 0xCE, 0x72, 0x03, 0x7D, 0x45, 0xA6, 0x72, 0xEC, 0xFE, 0xCE, 0xE0, 0x6A, 0x68, 0x02, 0x77, 0x09, 0x62, 0x65, 0x68, 0x61, 0x76, 0x69, 0x6F, 0x75, 0x72, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x77, 0x0A, 0x67, 0x65, 0x6E, 0x5F, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x2D, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x66, 0x69, 0x6C, 0x65, 0x5F, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0xE0, 0xCE, 0xFE, 0xEC, 0x72, 0xA6, 0x45, 0x7D, 0x03, 0x72, 0xCE, 0xC1, 0x11, 0xB7, 0x79, 0x86
.section .text {#0}
