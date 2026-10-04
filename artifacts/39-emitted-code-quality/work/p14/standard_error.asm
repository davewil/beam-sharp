    align 8
L125:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# standard_error:start_link/0
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x42, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_link/0:
# i_breakpoint_trampoline
    short jmp L127
.db 0x90
    call L128
L127:
# i_test_yield
    lea rdx, qword ptr [start_link/0+24]
    dec r14d
    long jle L129
    align 4
# i_move_sd
    mov qword ptr [rbx+8], 95051
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
L130:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_call_ext_only_e
L131:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_3:
# func_line_I
# i_func_info_IaaI
# standard_error:terminate/2
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x53, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
terminate/2:
# i_breakpoint_trampoline
    short jmp L132
.db 0x90
    call L128
L132:
# i_test_yield
    lea rdx, qword ptr [terminate/2+24]
    dec r14d
    long jle L129
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L133
    mov ecx, 2
    call 139636653423200
L133:
    sub rsp, 8
# catch_yf
    inc qword ptr [r13+256]
L134:
    mov eax, 2147483647
    mov qword ptr [rsp], rax
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 23435
# line_I
# call_light_bif_be
    align 4
L135:
L136:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092368
    lea rdx, qword ptr [L135]
# BIF: erlang:exit/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# try_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp], 59
# jump_f
    jmp label_6
# label_L
label_5:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# label_L
label_6:
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_7:
# func_line_I
# i_func_info_IaaI
# standard_error:init/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
init/1:
# i_breakpoint_trampoline
    short jmp L138
.db 0x90
    call L128
L138:
# i_test_yield
    lea rdx, qword ptr [init/1+24]
    dec r14d
    long jle L129
    align 4
# is_nil_fS
    cmp byte ptr [rbx], 59
    short jne label_7
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L139
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L139:
    sub rsp, 8
# catch_yf
    inc qword ptr [r13+256]
L140:
    mov eax, 2147483647
    mov qword ptr [rsp], rax
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call start/0
# label_L
label_9:
# catch_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp], 59
    cmp qword ptr [rbx], 0
    short jne L141
.db 0x90
    call 139636653422576
L141:
# is_pid_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L142
    test al, 1
    jne label_10
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_10
L142:
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
    mov qword ptr [r15+8], 32075
    mov rax, qword ptr [rbx]
    mov qword ptr [r15+16], rax
    mov qword ptr [r15+24], rax
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L137
    ret
# label_L
label_10:
# i_move_sd
L144:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_11:
# func_line_I
# i_func_info_IaaI
# standard_error:start/0
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xA7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start/0:
# i_breakpoint_trampoline
    short jmp L145
.db 0x90
    call L128
L145:
# i_test_yield
    lea rdx, qword ptr [start/0+24]
    dec r14d
    long jle L129
    align 4
# allocate_heap_tIt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L146
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L146:
    sub rsp, 8
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
L147:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L148:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 95051
# line_I
# call_light_bif_be
    align 4
L149:
L150:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094720
    lea rdx, qword ptr [L149]
# BIF: erlang:register/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_13:
# func_line_I
# i_func_info_IaaI
# standard_error:server/0
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x4A, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
server/0:
# i_breakpoint_trampoline
    short jmp L151
.db 0x90
    call L128
L151:
# i_test_yield
    lea rdx, qword ptr [server/0+24]
    dec r14d
    long jle L129
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L152
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L152:
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx], 45387
# line_I
# call_light_bif_be
    align 4
L153:
L154:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L153]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# line_I
# i_call_ext_e
L155:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_15
# i_move_sd
L156:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L157:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_call_last_ft
    jmp run/1
# label_L
label_15:
# line_I
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L158
# i_func_label_L
    nop
    align 8
label_16:
# func_line_I
# i_func_info_IaaI
# standard_error:run/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
run/1:
# i_breakpoint_trampoline
    short jmp L159
.db 0x90
    call L128
L159:
# i_test_yield
    lea rdx, qword ptr [run/1+24]
    dec r14d
    long jle L129
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L160
    mov ecx, 1
    call 139636653423200
L160:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# i_call_f
    call encoding/1
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 227211
# i_call_ext_e
L161:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx], 154635
# line_I
# i_call_ext_e
L162:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 477899
# i_call_ext_e
L163:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx+8], 1291
# i_move_sd
    mov qword ptr [rbx], 56651
# line_I
# i_call_ext_e
L164:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 8
    jmp server_loop/1
# i_func_label_L
    align 8
label_18:
# func_line_I
# i_func_info_IaaI
# standard_error:encoding/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x77, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
encoding/1:
# i_breakpoint_trampoline
    short jmp L165
.db 0x90
    call L128
L165:
# i_test_yield
    lea rdx, qword ptr [encoding/1+24]
    dec r14d
    long jle L129
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L166
    mov ecx, 1
    call 139636653423200
L166:
# line_I
# i_call_ext_e
L167:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_21
    cmp rsi, 75
    je label_20
    jmp label_22
# label_L
label_20:
# i_move_sd
    mov qword ptr [rbx], 46027
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_21:
# i_move_sd
    mov qword ptr [rbx], 23883
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_22:
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L158
# i_func_label_L
    nop
    align 8
label_23:
# func_line_I
# i_func_info_IaaI
# standard_error:server_loop/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xEE, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
server_loop/1:
# i_breakpoint_trampoline
    short jmp L168
.db 0x90
    call L128
L168:
# i_test_yield
    lea rdx, qword ptr [server_loop/1+24]
    dec r14d
    long jle L129
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L169
    mov ecx, 1
    call 139636653423200
L169:
    sub rsp, 24
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# aligned_label_Lt
    align 4
label_25:
# i_loop_rec_f
    align 4
L170:
    lea rdi, qword ptr [L170]
    lea rsi, qword ptr [label_28]
    call 139636653425768
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_27
    cmp dword ptr [rsi-2], 256
    jne label_27
    cmp qword ptr [rsi+6], 85259
    jne label_27
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# is_pid_fs
# simplified fetching of BEAM register
    mov rdi, r10
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L171
    test al, 1
    jne label_27
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_27
L171:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
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
# i_get_hash_cWd
    mov esi, 885
    mov edx, 56651
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436344672
    mov rsp, rbp
    mov qword ptr [rbx+8], rax
# i_move_sd
    mov qword ptr [rbx+16], 95051
# line_I
# i_call_ext_e
L172:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+16]
    mov qword ptr [rbx+8], r11
# line_I
# i_call_f
.db 0x66, 0x90
    call io_request/2
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+8], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r11
# i_get_tuple_element_sPS
    mov rdx, qword ptr [rsi+14]
    mov qword ptr [rbx], rdx
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r11, 43019
    jne label_26
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L173
    mov ecx, 2
    call 139636653423200
L173:
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
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_trim_t
    add rsp, 24
# line_I
# i_call_f
.db 0x66, 0x90
    call io_reply/3
# i_move_sd
    mov qword ptr [rbx], 43019
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_26:
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_trim_t
    add rsp, 16
# line_I
# i_call_f
    call io_reply/3
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 8
    jmp server_loop/1
# label_L
label_27:
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
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 24
    jmp server_loop/1
# aligned_label_Lt
    align 4
label_28:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_25]
    call 94068434775632
    mov rsp, rbp
    jmp L174
# i_func_label_L
    align 8
label_29:
# func_line_I
# i_func_info_IaaI
# standard_error:get_fd_geometry/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x4B, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_fd_geometry/1:
# i_breakpoint_trampoline
    short jmp L175
.db 0x90
    call L128
L175:
# i_test_yield
    lea rdx, qword ptr [get_fd_geometry/1+24]
    dec r14d
    long jle L129
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L176
    mov ecx, 1
    call 139636653423200
L176:
# line_I
# i_call_ext_e
L177:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_31
    cmp dword ptr [rsi-2], 128
    jne label_31
    cmp qword ptr [rsi+6], 32075
    jne label_31
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# i_is_tuple_of_arity_fsA
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_31
    cmp dword ptr [rsi-2], 128
    jne label_31
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_31:
# i_move_sd
    mov qword ptr [rbx], 779
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_32:
# func_line_I
# i_func_info_IaaI
# standard_error:io_request/2
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x4D, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
io_request/2:
# i_breakpoint_trampoline
    short jmp L178
.db 0x90
    call L128
L178:
# i_test_yield
    lea rdx, qword ptr [io_request/2+24]
    dec r14d
    long jle L129
    align 4
# i_is_tuple_fs
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_61
    test byte ptr [rsi-2], 63
    jne label_61
# i_select_tuple_arity_SfI
# skipped fetching of BEAM register
# skipped box test since argument is always boxed
    mov esi, dword ptr [rsi-2]
# simplified tuple test since the source is always a tuple when boxed
    cmp esi, 128
    je label_53
    cmp esi, 192
    je label_47
    cmp esi, 256
    je label_46
    cmp esi, 320
    je label_34
    jne label_62
# label_L
label_34:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 270603
    jne label_62
# load_tuple_ptr_s
# skipped fetching of BEAM register
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rbx+16], xmm0
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+30]
    vmovups xmmword ptr [rbx+32], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+16]
    cmp rsi, 23883
    je label_40
    cmp rsi, 46027
    je label_35
    jmp label_62
# label_L
label_35:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L179
    mov ecx, 6
.db 0x90
    call 139636653423200
L179:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# catch_yf
    inc qword ptr [r13+256]
L180:
    mov eax, 2147483647
    mov qword ptr [rsp+8], rax
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# line_I
# i_apply
    align 4
L182:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    xor edx, edx
    xor ecx, ecx
    call 94068435488720
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    short jne L181
    lea rsi, qword ptr [L182]
    mov rcx, 94068445024480
    push rsi
    jmp L183
L181:
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# label_L
label_36:
# catch_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+8], 59
    cmp qword ptr [rbx], 0
    short jne L184
    call 139636653422576
L184:
# is_list_fs
    mov rax, qword ptr [rbx]
    cmp rax, 59
    short je L185
    test al, 2
    jne label_37
L185:
# jump_f
    jmp label_38
# label_L
label_37:
# is_binary_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_52
    mov rax, qword ptr [rdi+6]
    mov esi, qword ptr [rdi-2]
    cmp esi, 292
    short jne L186
    mov rax, qword ptr [rdi+22]
    sub rax, qword ptr [rdi+14]
L186:
    shl eax, 29
    and esi, 59
    or esi, eax
    cmp esi, 32
    jne label_52
# label_L
label_38:
# i_get_hash_cWd
    mov esi, 3550
    mov edx, 227211
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436344672
    mov rsp, rbp
    mov qword ptr [rbx+16], rax
# i_move_sd
    mov qword ptr [rbx+8], 46027
# line_I
# i_call_f
    call wrap_characters_to_binary/3
# is_binary_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_39
    mov rax, qword ptr [rdi+6]
    mov esi, qword ptr [rdi-2]
    cmp esi, 292
    short jne L187
    mov rax, qword ptr [rdi+22]
    sub rax, qword ptr [rdi+14]
L187:
    shl eax, 29
    and esi, 59
    or esi, eax
    cmp esi, 32
    jne label_39
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_call_last_ft
    add rsp, 16
    jmp put_chars/2
# label_L
label_39:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_63
# jump_f
    jmp label_52
# label_L
label_40:
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L188
    mov ecx, 6
    call 139636653423200
L188:
    sub rsp, 24
# init_yregs_I
    mov qword ptr [rsp+8], 59
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# catch_yf
    inc qword ptr [r13+256]
L189:
    mov eax, 2147483647
    mov qword ptr [rsp+16], rax
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+32]
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# line_I
# i_apply
    align 4
L191:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    xor edx, edx
    xor ecx, ecx
    call 94068435488720
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    short jne L190
    lea rsi, qword ptr [L191]
    mov rcx, 94068445024480
    push rsi
    jmp L183
L190:
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# label_L
label_41:
# catch_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+16], 59
    cmp qword ptr [rbx], 0
    short jne L192
    call 139636653422576
L192:
# is_list_fs
    mov rax, qword ptr [rbx]
    cmp rax, 59
    short je L193
    test al, 2
    jne label_42
L193:
# jump_f
    jmp label_43
# label_L
label_42:
# is_binary_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_45
    mov rax, qword ptr [rdi+6]
    mov esi, qword ptr [rdi-2]
    cmp esi, 292
    short jne L194
    mov rax, qword ptr [rdi+22]
    sub rax, qword ptr [rdi+14]
L194:
    shl eax, 29
    and esi, 59
    or esi, eax
    cmp esi, 32
    jne label_45
# label_L
label_43:
# i_get_hash_cWd
    mov esi, 3550
    mov edx, 227211
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436344672
    mov rsp, rbp
    mov qword ptr [rbx+16], rax
# catch_yf
    inc qword ptr [r13+256]
L195:
    mov eax, 2147483647
    mov qword ptr [rsp+8], rax
# i_move_sd
    mov qword ptr [rbx+8], 23883
# line_I
# i_call_ext_e
L196:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# label_L
label_44:
# catch_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+8], 59
    cmp qword ptr [rbx], 0
    short jne L197
    call 139636653422576
L197:
# is_binary_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_45
    mov rax, qword ptr [rdi+6]
    mov esi, qword ptr [rdi-2]
    cmp esi, 292
    short jne L198
    mov rax, qword ptr [rdi+22]
    sub rax, qword ptr [rdi+14]
L198:
    shl eax, 29
    and esi, 59
    or esi, eax
    cmp esi, 32
    jne label_45
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_call_last_ft
    add rsp, 24
    jmp put_chars/2
# label_L
label_45:
# i_move_sd
L199:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
    add rsp, 24
# return
    dec r14d
    jl L137
    ret
# label_L
label_46:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 270603
    jne label_62
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L200
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L200:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rbx+16], xmm0
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+30]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 320
# Move tuple data
    mov qword ptr [r15+8], 270603
    mov qword ptr [r15+16], 23883
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx+16]
    vmovups xmmword ptr [r15+24], xmm0
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+40], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 48
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp io_request/2
# label_L
label_47:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 270603
    jne label_62
# load_tuple_ptr_s
# skipped fetching of BEAM register
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rbx+16], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+16]
    cmp rsi, 23883
    je label_50
    cmp rsi, 46027
    je label_48
    jmp label_62
# label_L
label_48:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L201
    mov ecx, 4
.db 0x66, 0x90
    call 139636653423200
L201:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# i_get_hash_cWd
    mov esi, 3550
    mov edx, 227211
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436344672
    mov rsp, rbp
    mov qword ptr [rbx+16], rax
# i_move_sd
    mov qword ptr [rbx+8], 46027
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
    call wrap_characters_to_binary/3
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 779
    jne label_49
# i_move_sd
L202:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L137
    ret
# label_L
label_49:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_call_last_ft
    add rsp, 8
    jmp put_chars/2
# label_L
label_50:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L203
    mov ecx, 4
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L203:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# i_get_hash_cWd
    mov esi, 3550
    mov edx, 227211
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436344672
    mov rsp, rbp
    mov qword ptr [rbx+16], rax
# catch_yf
    inc qword ptr [r13+256]
L204:
    mov eax, 2147483647
    mov qword ptr [rsp+8], rax
# i_move_sd
    mov qword ptr [rbx+8], 23883
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L205:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# label_L
label_51:
# catch_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+8], 59
    cmp qword ptr [rbx], 0
    short jne L206
    call 139636653422576
L206:
# is_binary_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_52
    mov rax, qword ptr [rdi+6]
    mov esi, qword ptr [rdi-2]
    cmp esi, 292
    short jne L207
    mov rax, qword ptr [rdi+22]
    sub rax, qword ptr [rdi+14]
L207:
    shl eax, 29
    and esi, 59
    or esi, eax
    cmp esi, 32
    jne label_52
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_call_last_ft
    add rsp, 16
    jmp put_chars/2
# label_L
label_52:
# i_move_sd
L208:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L137
    ret
# label_L
label_53:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+16], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+16]
    cmp rsi, 64267
    je label_54
    cmp rsi, 270603
    je label_56
    cmp rsi, 388875
    je label_55
    cmp rsi, 478155
    je label_57
    jmp label_62
# label_L
label_54:
# is_list_fs
    mov rax, qword ptr [rbx+24]
    cmp rax, 59
    short je L209
    test al, 2
    jne label_62
L209:
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], rax
# i_call_only_f
    jmp setopts/1
# label_L
label_55:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx+16], r10
# i_move_sd
L210:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp io_requests/3
# label_L
label_56:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L211
    mov ecx, 4
.db 0x90
    call 139636653423200
L211:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 270603
    mov qword ptr [r15+16], 23883
    mov rdi, qword ptr [rbx+24]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp io_request/2
# label_L
label_57:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+24]
    cmp rsi, 478219
    je label_59
    cmp rsi, 478283
    je label_58
    jmp label_62
# label_L
label_58:
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L212
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L212:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
    call get_fd_geometry/1
# i_is_tuple_fs
    mov rsi, qword ptr [rbx]
# simplified tuple test since the source is always a tuple when boxed
    rex test sil, 1
    jne label_60
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L213
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L213:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 37323
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
    jl L137
    ret
# label_L
label_59:
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L214
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L214:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
    call get_fd_geometry/1
# i_is_tuple_fs
    mov rsi, qword ptr [rbx]
# simplified tuple test since the source is always a tuple when boxed
    rex test sil, 1
    jne label_60
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L215
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L215:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 37323
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
    jl L137
    ret
# label_L
label_60:
# i_move_sd
L216:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_61:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 101067
    jne label_62
# i_call_only_f
    jmp getopts/0
# label_L
label_62:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L217
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L217:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 82955
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
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 37323
# simplified fetching of BEAM register
    mov rdi, r11
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L137
    ret
# label_L
label_63:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L158
# i_func_label_L
    nop
    align 8
label_64:
# func_line_I
# i_func_info_IaaI
# standard_error:io_requests/3
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x4C, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
io_requests/3:
# i_breakpoint_trampoline
    short jmp L218
.db 0x90
    call L128
L218:
# i_test_yield
    lea rdx, qword ptr [io_requests/3+24]
    dec r14d
    long jle L129
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_67
    mov rsi, qword ptr [rax-1]
    mov rdx, qword ptr [rax+7]
    mov qword ptr [rbx+24], rsi
    mov qword ptr [rbx], rdx
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx+8]
# skipped box test since argument is always boxed
    cmp dword ptr [rsi-2], 128
    jne label_68
    cmp qword ptr [rsi+6], 37323
    jne label_68
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+32], r10
# i_is_tagged_tuple_fsAa
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_66
    cmp dword ptr [rsi-2], 128
    jne label_66
    cmp qword ptr [rsi+6], 779
    jne label_66
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rbx], r11
# return
    dec r14d
    jl L137
    ret
# label_L
label_66:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L219
    mov ecx, 4
.db 0x66, 0x90
    call 139636653423200
L219:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+16]
    mov qword ptr [rsp+8], r11
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+16], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_f
    call io_request/2
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx+16], r11
# i_move_sd
    mov rdx, qword ptr [rsp]
    mov qword ptr [rbx], rdx
# i_call_last_ft
    add rsp, 16
    jmp io_requests/3
# label_L
label_67:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_64
# label_L
label_68:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_69:
# func_line_I
# i_func_info_IaaI
# standard_error:io_reply/3
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xEE, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
io_reply/3:
# i_breakpoint_trampoline
    short jmp L220
.db 0x90
    call L128
L220:
# i_test_yield
    lea rdx, qword ptr [io_reply/3+24]
    dec r14d
    long jle L129
    align 4
# allocate_heap_tIt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L221
    mov ecx, 3
    call 139636653423200
L221:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 388683
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx+8]
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx+8], r10
# line_I
# send
    align 4
L222:
    mov rcx, 94068445203056
    mov rax, 94068436096848
    lea rdx, qword ptr [L222]
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_71:
# func_line_I
# i_func_info_IaaI
# standard_error:put_chars/2
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x21, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
put_chars/2:
# i_breakpoint_trampoline
    short jmp L223
.db 0x90
    call L128
L223:
# i_test_yield
    lea rdx, qword ptr [put_chars/2+24]
    dec r14d
    long jle L129
    align 4
# is_binary_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    short jne label_71
    mov rax, qword ptr [rdi+6]
    mov esi, qword ptr [rdi-2]
    cmp esi, 292
    short jne L224
    mov rax, qword ptr [rdi+22]
    sub rax, qword ptr [rdi+14]
L224:
    shl eax, 29
    and esi, 59
    or esi, eax
    cmp esi, 32
    short jne label_71
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L225
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L225:
    sub rsp, 16
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+8], r10
# self_d
    mov r11, qword ptr [r13]
    mov qword ptr [rbx+16], r11
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_e
L226:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_is_tagged_tuple_fsAa
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_82
    cmp dword ptr [rsi-2], 128
    jne label_82
    cmp qword ptr [rsi+6], 32075
    jne label_82
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# init_yregs_I
    mov qword ptr [rsp+8], 59
# line_I
# i_call_ext_e
L227:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_81
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_81
# i_get_map_element_hash_fScWS
# skipped fetching of BEAM register
    mov esi, 96779
    mov rdx, 4017682383873878679
    call L228
    jne label_81
    mov qword ptr [rsp+8], rax
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rsp], r10
# aligned_label_Lt
    align 4
label_73:
# i_loop_rec_f
    align 4
L229:
    lea rdi, qword ptr [L229]
    lea rsi, qword ptr [label_79]
    call 139636653425768
# i_select_tuple_arity_SfI
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_78
    mov esi, dword ptr [rsi-2]
    rex test sil, 63
    jne label_78
    cmp esi, 128
    je label_77
    cmp esi, 320
    je label_74
    jne label_78
# label_L
label_74:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 1355
    jne label_78
# is_eq_exact_fss
    mov rsi, qword ptr [rsp]
    mov rdi, qword ptr [rbx+16]
    cmp rdi, rsi
    short je L230
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    je label_78
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_78
L230:
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
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
    mov qword ptr [rbx+8], 95051
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov qword ptr [rbx], 22027
# line_I
# i_call_ext_e
L231:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+38]
    mov qword ptr [rsp+8], r10
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_76
    cmp rsi, 75
    je label_75
    jmp label_80
# label_L
label_75:
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L232
    xor ecx, ecx
.db 0x90
    call 139636653423200
L232:
# put_cons_ss
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
    mov qword ptr [rbx+8], 22027
# i_move_sd
L233:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# i_move_sd
L234:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_call_ext_e
L235:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# label_L
label_76:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L236
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L236:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 43019
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L137
    ret
# label_L
label_77:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+6], 1
    vmovups xmmword ptr [rbx], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_78
# is_eq_exact_fss
    mov rsi, qword ptr [rsp+8]
    mov rdi, qword ptr [rbx+8]
    cmp rdi, rsi
    short je L237
    mov eax, edi
    or eax, esi
    and al, 3
    cmp al, 3
    je label_78
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_78
L237:
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
L238:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 16
# line_I
# call_light_bif_be
    align 4
L239:
L240:
    long mov rcx, 9223372036854775807
    mov rax, 94068436085312
    lea rdx, qword ptr [L239]
# BIF: erlang:demonitor/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
L241:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_78:
# loop_rec_end_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435274720
    mov rsp, rbp
    dec r14d
    jmp label_73
# aligned_label_Lt
    align 4
label_79:
# wait_locked_f
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [label_73]
    call 94068434775632
    mov rsp, rbp
    jmp L174
# label_L
label_80:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L158
# label_L
label_81:
# line_I
    nop
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L158
# label_L
label_82:
# line_I
    nop
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L158
# i_func_label_L
    nop
    align 8
label_83:
# func_line_I
# i_func_info_IaaI
# standard_error:setopts/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xFB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
setopts/1:
# i_breakpoint_trampoline
    short jmp L242
.db 0x90
    call L128
L242:
# i_test_yield
    lea rdx, qword ptr [setopts/1+24]
    dec r14d
    long jle L129
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L243
    mov ecx, 1
    call 139636653423200
L243:
    sub rsp, 8
# init_yregs_I
    mov qword ptr [rsp], 59
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call expand_encoding/1
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# i_call_f
    call check_valid_opts/1
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_85
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L244
    xor ecx, ecx
.db 0x90
    call 139636653423200
L244:
# i_move_sd
L245:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_trim_t
    add rsp, 8
# line_I
# i_call_ext_e
L246:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
L247:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_85:
# i_move_sd
L248:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_86:
# func_line_I
# i_func_info_IaaI
# standard_error:check_valid_opts/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xF2, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
check_valid_opts/1:
# i_breakpoint_trampoline
    short jmp L249
.db 0x90
    call L128
L249:
# i_test_yield
    lea rdx, qword ptr [check_valid_opts/1+24]
    dec r14d
    long jle L129
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_94
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rax-1], 1
    vmovups xmmword ptr [rbx], xmm0
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    jne label_93
    cmp dword ptr [rsi-2], 128
    jne label_93
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+6], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+16]
    cmp rsi, 56651
    je label_89
    cmp rsi, 227211
    je label_91
    cmp rsi, 477899
    je label_88
    jmp label_93
# label_L
label_88:
# is_boolean_fs
    mov rdi, qword ptr [rbx+8]
    and rdi, -65
    cmp rdi, 11
    jne label_93
# i_call_only_f
    jmp check_valid_opts/1
# label_L
label_89:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L250
    mov ecx, 2
    call 139636653423200
L250:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rbx], r11
# i_move_sd
L251:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# line_I
# call_light_bif_be
    align 4
L252:
L253:
    long mov rcx, 9223372036854775807
    mov rax, 94068435892832
    lea rdx, qword ptr [L252]
# BIF: lists:member/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_90
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 8
    jmp check_valid_opts/1
# label_L
label_90:
# i_move_sd
    mov qword ptr [rbx], 11
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L137
    ret
# label_L
label_91:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 23883
    je label_92
    cmp rsi, 46027
    je label_92
    cmp rsi, 46347
    je label_92
    jmp label_93
# label_L
label_92:
# i_call_only_f
    jmp check_valid_opts/1
# label_L
label_93:
# i_move_sd
    mov qword ptr [rbx], 11
# return
    dec r14d
    jl L137
    ret
# label_L
label_94:
# i_move_sd
    mov qword ptr [rbx], 75
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_95:
# func_line_I
# i_func_info_IaaI
# standard_error:expand_encoding/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xED, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
expand_encoding/1:
# i_breakpoint_trampoline
    short jmp L254
.db 0x90
    call L128
L254:
# i_test_yield
    lea rdx, qword ptr [expand_encoding/1+24]
    dec r14d
    long jle L129
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_102
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rax-1], 1
    vmovups xmmword ptr [rbx], xmm0
# is_eq_exact_fss
# optimized equality test with {encoding,utf8}
L255:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx+8]
    call L256
    jne label_97
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L257
    mov ecx, 1
.db 0x90
    call 139636653423200
L257:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call expand_encoding/1
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L258
    mov ecx, 1
    call 139636653423200
L258:
# put_cons_ss
L259:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_97:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 23883
    je label_100
    cmp rsi, 46027
    je label_99
    cmp rsi, 46347
    je label_98
    jmp label_101
# label_L
label_98:
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L260
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L260:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call expand_encoding/1
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L261
    mov ecx, 1
    call 139636653423200
L261:
# put_cons_ss
L262:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_99:
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L263
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L263:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call expand_encoding/1
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L264
    mov ecx, 1
    call 139636653423200
L264:
# put_cons_ss
L265:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_100:
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L266
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L266:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call expand_encoding/1
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L267
    mov ecx, 1
    call 139636653423200
L267:
# put_cons_ss
L268:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_101:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L269
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L269:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call expand_encoding/1
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L270
    mov ecx, 1
    call 139636653423200
L270:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L137
    ret
# label_L
label_102:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_95
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_103:
# func_line_I
# i_func_info_IaaI
# standard_error:getopts/0
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x8A, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
getopts/0:
# i_breakpoint_trampoline
    short jmp L271
.db 0x90
    call L128
L271:
# i_test_yield
    lea rdx, qword ptr [getopts/0+24]
    dec r14d
    long jle L129
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+176]
    cmp rdx, rsp
    short jbe L272
    xor ecx, ecx
    call 139636653423200
L272:
# i_get_hash_cWd
    mov esi, 3550
    mov edx, 227211
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436344672
    mov rsp, rbp
    mov qword ptr [rbx], rax
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 227211
# simplified fetching of BEAM register
    mov rdi, rax
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# i_get_hash_cWd
    mov esi, 7467
    mov edx, 477899
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436344672
    mov rsp, rbp
    mov qword ptr [rbx+8], rax
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 477899
# simplified fetching of BEAM register
    mov rdi, rax
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_get_hash_cWd
    mov esi, 885
    mov edx, 56651
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436344672
    mov rsp, rbp
    mov qword ptr [rbx+16], rax
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 56651
# simplified fetching of BEAM register
    mov rdi, rax
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+16], r10
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+16], rsi
# append_cons_Is
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
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
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 37323
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_105:
# func_line_I
# i_func_info_IaaI
# standard_error:wrap_characters_to_binary/3
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x4D, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
wrap_characters_to_binary/3:
# i_breakpoint_trampoline
    short jmp L273
.db 0x90
    call L128
L273:
# i_test_yield
    lea rdx, qword ptr [wrap_characters_to_binary/3+24]
    dec r14d
    long jle L129
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L274
    mov ecx, 3
    call 139636653423200
L274:
    sub rsp, 32
# init_yregs_I
    mov eax, 59
    mov qword ptr [rsp], rax
    mov qword ptr [rsp+24], rax
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp+16], r10
# i_get_hash_cWd
    mov esi, 7467
    mov edx, 477899
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436344672
    mov rsp, rbp
    mov qword ptr [rsp+8], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 23883
    jne label_107
# i_move_sd
    mov qword ptr [rsp], 4095
# jump_f
    jmp label_108
# label_L
label_107:
# i_move_sd
    mov qword ptr [rsp], 17825791
# label_L
label_108:
# catch_yf
    inc qword ptr [r13+256]
L275:
    mov eax, 2147483647
    mov qword ptr [rsp+24], rax
# line_I
# call_light_bif_be
    align 4
L276:
L277:
    long mov rcx, 9223372036854775807
    mov rax, 94068437166064
    lea rdx, qword ptr [L276]
# BIF: unicode:characters_to_list/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_109:
# catch_end_y
    dec qword ptr [r13+256]
    mov qword ptr [rsp+24], 59
    cmp qword ptr [rbx], 0
    short jne L278
    call 139636653422576
L278:
# is_list_fs
    mov rax, qword ptr [rbx]
    cmp rax, 59
    short je L279
    test al, 2
    jne label_110
L279:
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rsp+24], r10
# i_trim_t
    add rsp, 24
# line_I
# i_call_f
.db 0x66, 0x90
    call '-wrap_characters_to_binary/3-lc$^0/1-0-'/3
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov qword ptr [rbx+8], 46027
# line_I
# i_call_ext_last_et
    add rsp, 8
L280:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_110:
# i_move_sd
    mov qword ptr [rbx], 779
# deallocate_t
    add rsp, 32
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_111:
# func_line_I
# i_func_info_IaaI
# standard_error:module_info/0
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L281
.db 0x90
    call L128
L281:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L129
    align 4
# i_move_sd
    mov qword ptr [rbx], 95051
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L282
    mov ecx, 1
.db 0x90
    call 139636653423200
L282:
# call_light_bif_be
    align 4
L283:
L284:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L283]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_113:
# func_line_I
# i_func_info_IaaI
# standard_error:module_info/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L285
.db 0x90
    call L128
L285:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L129
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 95051
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L286
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L286:
# call_light_bif_be
    align 4
L287:
L288:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L287]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# i_func_label_L
    align 8
label_115:
# func_line_I
# i_func_info_IaaI
# standard_error:'-wrap_characters_to_binary/3-lc$^0/1-0-'/3
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x4D, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-wrap_characters_to_binary/3-lc$^0/1-0-'/3:
# i_breakpoint_trampoline
    short jmp L289
.db 0x90
    call L128
L289:
# i_test_yield
    lea rdx, qword ptr ['-wrap_characters_to_binary/3-lc$^0/1-0-'/3+24]
    dec r14d
    long jle L129
    align 4
# is_nonempty_list_fS
    test byte ptr [rbx], 2
    jne label_119
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L290
    mov ecx, 3
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L290:
    sub rsp, 32
# init_yregs_I
    mov qword ptr [rsp+8], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp+16], xmm0
# get_list_Sdd
    mov rdi, qword ptr [rbx]
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rdi-1], 1
    vmovups xmmword ptr [rsp], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rsp+8], 175
    jne label_117
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 75
    jne label_117
# i_move_sd
L291:
    long mov rdi, 9223372036854775807
    mov qword ptr [rsp+8], rdi
# jump_f
    jmp label_118
# label_L
label_117:
# is_lt_fss
    mov rsi, qword ptr [rsp+8]
    mov rdi, qword ptr [rbx+8]
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L292
    cmp rdi, rsi
    short jmp L293
L292:
    call L295
L293:
    jge label_118
L294:
# i_move_sd
    mov qword ptr [rbx+8], 271
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# init_yregs_I
    mov qword ptr [rsp+8], 59
# line_I
# call_light_bif_be
    align 4
L296:
L297:
    long mov rcx, 9223372036854775807
    mov rax, 94068436124864
    lea rdx, qword ptr [L296]
# BIF: erlang:integer_to_list/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L298
    mov ecx, 1
    call 139636653423200
L298:
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
L299:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
L300:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp+8], rsi
# label_L
label_118:
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+16], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rsp+24], r11
# i_trim_t
    add rsp, 24
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call '-wrap_characters_to_binary/3-lc$^0/1-0-'/3
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L301
    mov ecx, 1
    call 139636653423200
L301:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L137
    ret
# label_L
label_119:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_120
# return
    dec r14d
    jl L137
    ret
# label_L
label_120:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L302
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L302:
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
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L303
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L303:
# call_light_bif_be
    align 4
L304:
L305:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L304]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_121:
# func_line_I
# i_func_info_IaaI
# standard_error:'-setopts/1-fun-0-'/1
    call L126
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x4B, 0x73, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x4D, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-setopts/1-fun-0-'/1:
# i_breakpoint_trampoline
    short jmp L306
.db 0x90
    call L128
L306:
# i_test_yield
    lea rdx, qword ptr ['-setopts/1-fun-0-'/1+24]
    dec r14d
    long jle L129
    align 4
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    short jne label_121
    cmp dword ptr [rsi-2], 128
    short jne label_121
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 56651
    je label_124
    cmp rsi, 227211
    je label_125
    cmp rsi, 477899
    je label_123
    jmp label_121
# label_L
label_123:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 477899
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L307
    mov ecx, 2
.db 0x90
    call 139636653423200
L307:
# i_call_ext_e
L308:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_124:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 56651
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L309
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L309:
# i_call_ext_e
L310:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# label_L
label_125:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 227211
# line_I
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L311
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L311:
# i_call_ext_e
L312:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# deallocate_t
# return
    dec r14d
    jl L137
    ret
# int_code_end
L313:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L295:
    jmp 139636653420712
L183:
    jmp 139636653427784
L174:
    jmp 139636653427727
L256:
    jmp 139636653426424
L158:
    jmp 139636653427776
L228:
    jmp 139636653425144
L137:
    jmp 139636653422960
L129:
    jmp 139636653426040
L128:
    jmp 139636653424496
L126:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x02, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0x12, 0xD5, 0xF8, 0xDA, 0x3A, 0xB7, 0xFC, 0x77, 0x18, 0x58, 0xF6, 0x0B, 0x6D, 0x0D, 0x0A, 0x8A, 0x6A, 0x68, 0x02, 0x77, 0x09, 0x62, 0x65, 0x68, 0x61, 0x76, 0x69, 0x6F, 0x75, 0x72, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x77, 0x11, 0x73, 0x75, 0x70, 0x65, 0x72, 0x76, 0x69, 0x73, 0x6F, 0x72, 0x5F, 0x62, 0x72, 0x69, 0x64, 0x67, 0x65, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x30, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x73, 0x74, 0x61, 0x6E, 0x64, 0x61, 0x72, 0x64, 0x5F, 0x65, 0x72, 0x72, 0x6F, 0x72, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0x8A, 0x0A, 0x0D, 0x6D, 0x0B, 0xF6, 0x58, 0x18, 0x77, 0xFC, 0xB7, 0x3A, 0xDA, 0xF8, 0xD5, 0x12
.section .text {#0}
