    align 8
L83:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# kernel:start/2
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xA7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start/2:
# i_breakpoint_trampoline
    short jmp L85
.db 0x90
    call L86
L85:
# i_test_yield
    lea rdx, qword ptr [start/2+24]
    dec r14d
    long jle L87
    align 4
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    short jne label_1
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L88
    xor ecx, ecx
.db 0x90
    call 139636653423200
L88:
    sub rsp, 8
# init_yregs_I
    mov qword ptr [rsp], 59
# line_I
# i_call_ext_e
L89:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_7
# line_I
# i_call_ext_e
L90:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_6
# i_move_sd
    mov qword ptr [rbx+8], 180107
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
L91:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L92:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_is_tagged_tuple_fsAa
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_3
    cmp dword ptr [rsi-2], 128
    jne label_3
    cmp qword ptr [rsi+6], 32075
    jne label_3
# line_I
# i_call_ext_e
L93:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_5
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L94:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_4
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L95
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L95:
# load_tuple_ptr_s
    mov rsi, qword ptr [rsp]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 32075
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], 59
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r11
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L96
    ret
# label_L
label_3:
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L96
    ret
# label_L
label_4:
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L97
# label_L
label_5:
# line_I
    nop
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L97
# label_L
label_6:
# line_I
    nop
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L97
# label_L
label_7:
# line_I
    nop
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L97
# i_func_label_L
    nop
    align 8
label_8:
# func_line_I
# i_func_info_IaaI
# kernel:stop/1
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xA8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
stop/1:
# i_breakpoint_trampoline
    short jmp L98
.db 0x90
    call L86
L98:
# i_test_yield
    lea rdx, qword ptr [stop/1+24]
    dec r14d
    long jle L87
    align 4
# i_move_sd
    mov qword ptr [rbx], 32075
# return
    dec r14d
    jl L96
    ret
# i_func_label_L
    align 8
label_10:
# func_line_I
# i_func_info_IaaI
# kernel:config_change/3
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x50, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
config_change/3:
# i_breakpoint_trampoline
    short jmp L99
.db 0x90
    call L86
L99:
# i_test_yield
    lea rdx, qword ptr [config_change/3+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L100
    mov ecx, 3
    call 139636653423200
L100:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# line_I
# i_call_ext_e
L101:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_12
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
.db 0x66, 0x90
    call do_distribution_change/3
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 24
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call do_global_groups_change/3
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_12:
# line_I
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L97
# i_func_label_L
    nop
    align 8
label_13:
# func_line_I
# i_func_info_IaaI
# kernel:init/1
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
init/1:
# i_breakpoint_trampoline
    short jmp L102
.db 0x90
    call L86
L102:
# i_test_yield
    lea rdx, qword ptr [init/1+24]
    dec r14d
    long jle L87
    align 4
# is_atom_fs
    mov rax, qword ptr [rbx]
    and al, 63
    cmp al, 11
    jne label_17
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 32331
    je label_16
    cmp rsi, 38859
    je label_15
    short jmp label_13
# label_L
label_15:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L103
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L103:
    sub rsp, 16
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call start_boot_server/0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call start_disk_log/0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# i_call_f
    call start_pg/0
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
L104:
L105:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L104]
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
# call_light_bif_be
    align 4
L106:
L107:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L106]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L108
    mov ecx, 1
    call 139636653423200
L108:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
L109:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+8], rdi
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
    mov qword ptr [r15+8], 32075
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
    jl L96
    ret
# label_L
label_16:
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L110
    xor ecx, ecx
.db 0x90
    call 139636653423200
L110:
# line_I
# i_call_ext_e
L111:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L112
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L112:
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 32075
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# line_I
# i_call_ext_last_et
L113:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_17:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_13
# allocate_tt
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L114
    xor ecx, ecx
    call 139636653423200
L114:
    sub rsp, 40
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    mov ecx, 5
    rep stos qword ptr [rdi], rax
# line_I
# i_call_ext_e
L115:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_18
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_18
    cmp edi, 128
    jne label_25
    cmp qword ptr [rsi+6], 32075
    jne label_25
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L116
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L116:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
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
    mov qword ptr [rbx], rsi
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp+32], rsi
# jump_f
    jmp label_19
# label_L
label_18:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 1291
    jne label_25
# i_move_sd
    mov qword ptr [rsp+32], 59
# label_L
label_19:
# i_move_sd
    mov qword ptr [rbx], 180875
# line_I
# i_call_ext_e
L117:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_20
    cmp dword ptr [rsi-2], 128
    jne label_20
    cmp qword ptr [rsi+6], 32075
    jne label_20
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_nonempty_list_get_list_fSdd
# simplified fetching of BEAM register
    mov rax, r10
    test al, 2
    jne label_20
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rax-1], 1
    vmovups xmmword ptr [rbx], xmm0
# is_nonempty_list_get_tl_fSd
    mov rax, qword ptr [rbx+8]
    test al, 2
    jne label_20
    mov rsi, qword ptr [rax+7]
    mov qword ptr [rbx+8], rsi
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    jne label_20
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_20
# i_move_sd
L118:
    long mov rdi, 9223372036854775807
    mov qword ptr [rsp+16], rdi
# i_move_sd
    mov qword ptr [rsp+24], 59
# jump_f
    jmp label_21
# label_L
label_20:
# i_move_sd
    mov qword ptr [rsp+16], 59
# i_move_sd
L119:
    long mov rdi, 9223372036854775807
    mov qword ptr [rsp+24], rdi
# label_L
label_21:
# i_move_sd
    mov qword ptr [rbx], 83019
# line_I
# i_call_ext_e
L120:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_22
    cmp dword ptr [rsi-2], 128
    jne label_22
    cmp qword ptr [rsi+6], 32075
    jne label_22
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_nonempty_list_get_hd_fSd
# simplified fetching of BEAM register
    mov rax, r10
    test al, 2
    jne label_22
    mov rsi, qword ptr [rax-1]
    mov qword ptr [rbx], rsi
# is_eq_exact_fss
L122:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    cmp rdi, rsi
    short je L121
    rex test dil, 2
    jne label_22
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_22
L121:
# i_move_sd
L123:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r10, qword ptr [rsp+32]
    mov qword ptr [rbx], r10
# init_yregs_I
    mov qword ptr [rsp+32], 59
# line_I
# call_light_bif_be
    align 4
L124:
L125:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L124]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L126
    mov ecx, 1
    call 139636653423200
L126:
# put_cons_ss
L127:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 24
# line_I
# call_light_bif_be
    align 4
L128:
L129:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L128]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L130
    mov ecx, 1
    call 139636653423200
L130:
# put_cons_ss
L131:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
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
    add rsp, 16
# line_I
# call_light_bif_be
    align 4
L132:
L133:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L132]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+112]
    cmp rdx, rsp
    short jbe L134
    mov ecx, 1
    call 139636653423200
L134:
# put_cons_ss
L135:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
L136:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
L137:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+8], rdi
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 32075
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
    jl L96
    ret
# label_L
label_22:
# i_move_sd
    mov qword ptr [rbx+8], 398667
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L138:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# optimized equality test with {ok,false}
L139:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    call L140
    jne label_23
# i_move_sd
    mov qword ptr [rsp+8], 59
# jump_f
    jmp label_24
# label_L
label_23:
# line_I
# i_call_f
.db 0x90
    call start_distribution/0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# label_L
label_24:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call start_timer/0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# i_call_f
    call start_compile_server/0
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
L141:
L142:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L141]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
L143:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# call_light_bif_be
    align 4
L144:
L145:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L144]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+24]
    mov qword ptr [rbx], r11
# init_yregs_I
    mov qword ptr [rsp+24], 59
# line_I
# call_light_bif_be
    align 4
L146:
L147:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L146]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L148
    mov ecx, 1
    call 139636653423200
L148:
# put_cons_ss
L149:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# init_yregs_I
    mov qword ptr [rsp+8], 59
# line_I
# call_light_bif_be
    align 4
L150:
L151:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L150]
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
    add rsp, 16
# call_light_bif_be
    align 4
L152:
L153:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L152]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L154
    mov ecx, 1
    call 139636653423200
L154:
# put_cons_ss
L155:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# append_cons_Is
L156:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 16
# line_I
# call_light_bif_be
    align 4
L157:
L158:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L157]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+112]
    cmp rdx, rsp
    short jbe L159
    mov ecx, 1
    call 139636653423200
L159:
# put_cons_ss
L160:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
L161:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
L162:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+8], rdi
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 32075
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
    jl L96
    ret
# label_L
label_25:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L97
# i_func_label_L
    nop
    align 8
label_26:
# func_line_I
# i_func_info_IaaI
# kernel:start_distribution/0
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x15, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_distribution/0:
# i_breakpoint_trampoline
    short jmp L163
.db 0x90
    call L86
L163:
# i_test_yield
    lea rdx, qword ptr [start_distribution/0+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L164
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L164:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call start_dist_ac/0
# i_move_sd
L165:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# line_I
# call_light_bif_be
    align 4
L166:
L167:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L166]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L168
    mov ecx, 1
    call 139636653423200
L168:
# put_cons_ss
L169:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
L170:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# i_func_label_L
    align 8
label_28:
# func_line_I
# i_func_info_IaaI
# kernel:start_dist_ac/0
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x15, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_dist_ac/0:
# i_breakpoint_trampoline
    short jmp L171
.db 0x90
    call L86
L171:
# i_test_yield
    lea rdx, qword ptr [start_dist_ac/0+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L172
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L172:
# i_move_sd
    mov qword ptr [rbx+8], 398731
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L173:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_31
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_31
    cmp edi, 128
    jne label_33
    cmp qword ptr [rsi+6], 32075
    jne label_33
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r10
    cmp rsi, 11
    je label_32
    cmp rsi, 75
    je label_30
    jmp label_33
# label_L
label_30:
# i_move_sd
L174:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_31:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 907
    jne label_33
# i_move_sd
    mov qword ptr [rbx+8], 219275
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L175:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_32
    cmp dword ptr [rsi-2], 128
    jne label_32
    cmp qword ptr [rsi+6], 32075
    jne label_32
# i_move_sd
L176:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_32:
# i_move_sd
    mov qword ptr [rbx], 59
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_33:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L97
# i_func_label_L
    nop
    align 8
label_34:
# func_line_I
# i_func_info_IaaI
# kernel:start_boot_server/0
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x15, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_boot_server/0:
# i_breakpoint_trampoline
    short jmp L177
.db 0x90
    call L86
L177:
# i_test_yield
    lea rdx, qword ptr [start_boot_server/0+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L178
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L178:
# i_move_sd
    mov qword ptr [rbx+8], 398795
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L179:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# optimized equality test with {ok,true}
L180:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    call L140
    jne label_36
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call get_boot_args/0
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L181
    mov ecx, 1
    call 139636653423200
L181:
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 205387
    mov qword ptr [r15+16], 213707
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+112]
    cmp rdx, rsp
    short jbe L182
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L182:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 6
L183:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], 213899
    mov qword ptr [r15+32], 34187
    mov qword ptr [r15+40], 16015
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+48], rdi
    mov qword ptr [r15+56], 269259
L184:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+64], rdi
    lea rdi, byte ptr [r15+2]
    add r15, 72
    mov qword ptr [rbx], rdi
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L185
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L185:
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_36:
# i_move_sd
    mov qword ptr [rbx], 59
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# i_func_label_L
    align 8
label_37:
# func_line_I
# i_func_info_IaaI
# kernel:get_boot_args/0
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x16, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_boot_args/0:
# i_breakpoint_trampoline
    short jmp L186
.db 0x90
    call L86
L186:
# i_test_yield
    lea rdx, qword ptr [get_boot_args/0+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L187
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L187:
# i_move_sd
    mov qword ptr [rbx+8], 398923
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L188:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_39
    cmp dword ptr [rsi-2], 128
    jne label_39
    cmp qword ptr [rsi+6], 32075
    jne label_39
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_39:
# i_move_sd
    mov qword ptr [rbx], 59
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# i_func_label_L
    align 8
label_40:
# func_line_I
# i_func_info_IaaI
# kernel:start_disk_log/0
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x16, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_disk_log/0:
# i_breakpoint_trampoline
    short jmp L189
.db 0x90
    call L86
L189:
# i_test_yield
    lea rdx, qword ptr [start_disk_log/0+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L190
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L190:
# i_move_sd
    mov qword ptr [rbx+8], 398987
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L191:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# optimized equality test with {ok,true}
L192:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    call L140
    jne label_42
# i_move_sd
L193:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_42:
# i_move_sd
    mov qword ptr [rbx], 59
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# i_func_label_L
    align 8
label_43:
# func_line_I
# i_func_info_IaaI
# kernel:start_pg/0
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x16, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_pg/0:
# i_breakpoint_trampoline
    short jmp L194
.db 0x90
    call L86
L194:
# i_test_yield
    lea rdx, qword ptr [start_pg/0+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L195
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L195:
# i_move_sd
    mov qword ptr [rbx+8], 399051
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L196:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# optimized equality test with {ok,true}
L197:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    call L140
    jne label_45
# i_move_sd
L198:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_45:
# i_move_sd
    mov qword ptr [rbx], 59
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# i_func_label_L
    align 8
label_46:
# func_line_I
# i_func_info_IaaI
# kernel:start_timer/0
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0xDE, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_timer/0:
# i_breakpoint_trampoline
    short jmp L199
.db 0x90
    call L86
L199:
# i_test_yield
    lea rdx, qword ptr [start_timer/0+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L200
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L200:
# i_move_sd
    mov qword ptr [rbx+8], 57035
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L201:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# optimized equality test with {ok,true}
L202:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    call L140
    jne label_48
# i_move_sd
L203:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_48:
# i_move_sd
    mov qword ptr [rbx], 59
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# i_func_label_L
    align 8
label_49:
# func_line_I
# i_func_info_IaaI
# kernel:start_compile_server/0
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x17, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_compile_server/0:
# i_breakpoint_trampoline
    short jmp L204
.db 0x90
    call L86
L204:
# i_test_yield
    lea rdx, qword ptr [start_compile_server/0+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L205
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L205:
# i_move_sd
    mov qword ptr [rbx+8], 399115
# i_move_sd
    mov qword ptr [rbx], 180107
# line_I
# i_call_ext_e
L206:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# optimized equality test with {ok,true}
L207:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    call L140
    jne label_51
# i_move_sd
L208:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_51:
# i_move_sd
    mov qword ptr [rbx], 59
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# i_func_label_L
    align 8
label_52:
# func_line_I
# i_func_info_IaaI
# kernel:do_distribution_change/3
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x17, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_distribution_change/3:
# i_breakpoint_trampoline
    short jmp L209
.db 0x90
    call L86
L209:
# i_test_yield
    lea rdx, qword ptr [do_distribution_change/3+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L210
    mov ecx, 3
    call 139636653423200
L210:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call is_dist_changed/3
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+24], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 11
    jne label_54
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 11
    jne label_55
# is_ne_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 75
    je label_55
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_54:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 11
    jne label_55
# is_ne_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 75
    je label_55
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L211
    mov ecx, 2
    call 139636653423200
L211:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 399243
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx+16], 395
# i_move_sd
    mov qword ptr [rbx], 205259
# i_call_ext_last_et
L212:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_55:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 11
    jne label_57
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 75
    jne label_56
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 11
    jne label_57
# i_move_sd
L213:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L214:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_move_sd
L215:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_56:
# i_move_sd
L216:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L217:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
L218:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_57:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L97
# i_func_label_L
    nop
    align 8
label_58:
# func_line_I
# i_func_info_IaaI
# kernel:is_dist_changed/3
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x17, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
is_dist_changed/3:
# i_breakpoint_trampoline
    short jmp L219
.db 0x90
    call L86
L219:
# i_test_yield
    lea rdx, qword ptr [is_dist_changed/3+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L220
    mov ecx, 3
    call 139636653423200
L220:
    sub rsp, 24
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov qword ptr [rbx+8], 31
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov qword ptr [rbx], 219275
# line_I
# call_light_bif_be
    align 4
L221:
L222:
    long mov rcx, 9223372036854775807
    mov rax, 94068435894080
    lea rdx, qword ptr [L221]
# BIF: lists:keyfind/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_60
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_60
    cmp edi, 128
    jne label_64
    cmp qword ptr [rsi+6], 219275
    jne label_64
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp], r10
# jump_f
    jmp label_61
# label_L
label_60:
# i_move_sd
    mov qword ptr [rsp], 11
# label_L
label_61:
# i_move_sd
    mov qword ptr [rbx+8], 31
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx+16], r10
# init_yregs_I
    mov qword ptr [rsp+16], 59
# i_move_sd
    mov qword ptr [rbx], 219275
# line_I
# call_light_bif_be
    align 4
L223:
L224:
    long mov rcx, 9223372036854775807
    mov rax, 94068435894080
    lea rdx, qword ptr [L223]
# BIF: lists:keyfind/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_62
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_62
    cmp edi, 128
    jne label_65
    cmp qword ptr [rsi+6], 219275
    jne label_65
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp+16], r10
# jump_f
    jmp label_63
# label_L
label_62:
# i_move_sd
    mov qword ptr [rsp+16], 11
# label_L
label_63:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rsp+8], r11
# i_trim_t
    add rsp, 8
# i_move_sd
    mov qword ptr [rbx], 219275
# line_I
# call_light_bif_be
    align 4
L225:
L226:
    long mov rcx, 9223372036854775807
    mov rax, 94068435892832
    lea rdx, qword ptr [L225]
# BIF: lists:member/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L227
    mov ecx, 1
    call 139636653423200
L227:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rsp]
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
    jl L96
    ret
# label_L
label_64:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L97
# label_L
label_65:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L97
# i_func_label_L
    nop
    align 8
label_66:
# func_line_I
# i_func_info_IaaI
# kernel:do_global_groups_change/3
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x18, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_global_groups_change/3:
# i_breakpoint_trampoline
    short jmp L228
.db 0x90
    call L86
L228:
# i_test_yield
    lea rdx, qword ptr [do_global_groups_change/3+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L229
    mov ecx, 3
    call 139636653423200
L229:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call is_gg_changed/3
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+8], xmm0
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+24], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 11
    jne label_68
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 11
    jne label_69
# is_ne_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 75
    je label_69
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# label_L
label_68:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 11
    jne label_69
# is_ne_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 75
    je label_69
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_call_ext_last_et
L230:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_69:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 11
    jne label_71
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+24], 75
    jne label_70
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 11
    jne label_71
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# i_call_ext_last_et
L231:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_70:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx], r10
# i_call_ext_last_et
L232:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_71:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L97
# i_func_label_L
    nop
    align 8
label_72:
# func_line_I
# i_func_info_IaaI
# kernel:is_gg_changed/3
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x19, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
is_gg_changed/3:
# i_breakpoint_trampoline
    short jmp L233
.db 0x90
    call L86
L233:
# i_test_yield
    lea rdx, qword ptr [is_gg_changed/3+24]
    dec r14d
    long jle L87
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L234
    mov ecx, 3
    call 139636653423200
L234:
    sub rsp, 24
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov qword ptr [rbx+8], 31
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov qword ptr [rbx], 399691
# line_I
# call_light_bif_be
    align 4
L235:
L236:
    long mov rcx, 9223372036854775807
    mov rax, 94068435894080
    lea rdx, qword ptr [L235]
# BIF: lists:keyfind/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_74
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_74
    cmp edi, 128
    jne label_78
    cmp qword ptr [rsi+6], 399691
    jne label_78
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp], r10
# jump_f
    jmp label_75
# label_L
label_74:
# i_move_sd
    mov qword ptr [rsp], 11
# label_L
label_75:
# i_move_sd
    mov qword ptr [rbx+8], 31
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx+16], r10
# init_yregs_I
    mov qword ptr [rsp+16], 59
# i_move_sd
    mov qword ptr [rbx], 399691
# line_I
# call_light_bif_be
    align 4
L237:
L238:
    long mov rcx, 9223372036854775807
    mov rax, 94068435894080
    lea rdx, qword ptr [L237]
# BIF: lists:keyfind/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_is_tagged_tuple_ff_ffsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_76
    mov rdi, qword ptr [rsi-2]
    rex test dil, 63
    jne label_76
    cmp edi, 128
    jne label_79
    cmp qword ptr [rsi+6], 399691
    jne label_79
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp+16], r10
# jump_f
    jmp label_77
# label_L
label_76:
# i_move_sd
    mov qword ptr [rsp+16], 11
# label_L
label_77:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rsp+8], r11
# i_trim_t
    add rsp, 8
# i_move_sd
    mov qword ptr [rbx], 399691
# line_I
# call_light_bif_be
    align 4
L239:
L240:
    long mov rcx, 9223372036854775807
    mov rax, 94068435892832
    lea rdx, qword ptr [L239]
# BIF: lists:member/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L241
    mov ecx, 1
    call 139636653423200
L241:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rsp]
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
    jl L96
    ret
# label_L
label_78:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L97
# label_L
label_79:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L97
# i_func_label_L
    nop
    align 8
label_80:
# func_line_I
# i_func_info_IaaI
# kernel:module_info/0
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L242
.db 0x90
    call L86
L242:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L87
    align 4
# i_move_sd
    mov qword ptr [rbx], 180107
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L243
    mov ecx, 1
.db 0x90
    call 139636653423200
L243:
# call_light_bif_be
    align 4
L244:
L245:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L244]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# i_func_label_L
    align 8
label_82:
# func_line_I
# i_func_info_IaaI
# kernel:module_info/1
    call L84
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0xBF, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L246
.db 0x90
    call L86
L246:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L87
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 180107
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L247
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L247:
# call_light_bif_be
    align 4
L248:
L249:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L248]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L96
    ret
# int_code_end
L250:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L140:
    jmp 139636653426424
L97:
    jmp 139636653427776
L96:
    jmp 139636653422960
L87:
    jmp 139636653426040
L86:
    jmp 139636653424496
L84:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x02, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0x08, 0x6F, 0xC6, 0xA0, 0xB5, 0x5E, 0xA6, 0xA9, 0x93, 0x75, 0x62, 0x18, 0x86, 0xE7, 0x3B, 0xBD, 0x6A, 0x68, 0x02, 0x77, 0x09, 0x62, 0x65, 0x68, 0x61, 0x76, 0x69, 0x6F, 0x75, 0x72, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x77, 0x0A, 0x73, 0x75, 0x70, 0x65, 0x72, 0x76, 0x69, 0x73, 0x6F, 0x72, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0xBD, 0x3B, 0xE7, 0x86, 0x18, 0x62, 0x75, 0x93, 0xA9, 0xA6, 0x5E, 0xB5, 0xA0, 0xC6, 0x6F, 0x08
.section .text {#0}
