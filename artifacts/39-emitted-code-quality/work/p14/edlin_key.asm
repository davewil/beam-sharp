    align 8
L89:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# edlin_key:get_key_map/0
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xD5, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_key_map/0:
# i_breakpoint_trampoline
    short jmp L91
.db 0x90
    call L92
L91:
# i_test_yield
    lea rdx, qword ptr [get_key_map/0+24]
    dec r14d
    long jle L93
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L94
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L94:
# i_move_sd
    mov qword ptr [rbx+8], 583051
# i_move_sd
    mov qword ptr [rbx+16], 1291
# i_move_sd
    mov qword ptr [rbx], 215435
# line_I
# i_call_ext_e
L95:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 1291
    jne label_3
# i_call_last_ft
    jmp key_map/0
# label_L
label_3:
# i_call_last_ft
    jmp merge/1
# i_func_label_L
    align 8
label_4:
# func_line_I
# i_func_info_IaaI
# edlin_key:get_valid_escape_key/2
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xD6, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_valid_escape_key/2:
# i_breakpoint_trampoline
    short jmp L96
.db 0x90
    call L92
L96:
# i_test_yield
    lea rdx, qword ptr [get_valid_escape_key/2+24]
    dec r14d
    long jle L93
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_42
# (moving head and tail together)
    vmovups xmm0, xmmword ptr [rax-1]
    vmovups xmmword ptr [rbx+16], xmm0
# i_is_tuple_of_arity_ff_ffsA
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    jne label_17
    mov eax, dword ptr [rsi-2]
    test al, 63
    jne label_17
    cmp eax, 128
    jne label_57
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx+32], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+32]
    cmp rsi, 125707
    je label_6
    cmp rsi, 583115
    je label_8
    jmp label_57
# label_L
label_6:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 2031
    jne label_7
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L97
    mov ecx, 6
    call 139636653423200
L97:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rsp], r10
# i_move_sd
L98:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r11, qword ptr [rbx+40]
    mov qword ptr [rbx], r11
# line_I
# call_light_bif_be
    align 4
L99:
L100:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L99]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L101
    mov ecx, 1
    call 139636653423200
L101:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 125707
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 59
# i_call_last_ft
    add rsp, 8
    jmp get_valid_escape_key/2
# label_L
label_7:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L102
    mov ecx, 6
.db 0x66, 0x90
    call 139636653423200
L102:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 125707
    mov rdi, qword ptr [rbx+40]
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 59
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_8:
# is_nonempty_list_get_hd_fSd
    mov rax, qword ptr [rbx+40]
    test al, 2
    jne label_10
    mov rsi, qword ptr [rax-1]
    mov qword ptr [rbx], rsi
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rsi, 959
    jne label_10
# is_ge_lt_ffScc
    mov esi, 783
    mov edx, 927
    mov rdi, qword ptr [rbx+16]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L103
    cmp rdi, rsi
    jl label_9
    cmp rdx, rdi
    jge label_14
    short jmp L104
L103:
    call L105
    jl label_9
    jg label_14
L104:
# label_L
label_9:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L106
    mov ecx, 6
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L106:
    sub rsp, 16
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+16]
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+40]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L107:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L108
    mov ecx, 1
    call 139636653423200
L108:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# i_trim_t
    add rsp, 8
# call_light_bif_be
    align 4
L109:
L110:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L109]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L111
    mov ecx, 1
    call 139636653423200
L111:
# put_cons_ss
    mov qword ptr [r15], 1471
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 447
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 22795
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp get_valid_escape_key/2
# label_L
label_10:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+16]
    cmp rsi, 959
    je label_12
    cmp rsi, 2031
    je label_11
    jmp label_13
# label_L
label_11:
# allocate_heap_tIt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L112
    mov ecx, 6
.db 0x66, 0x90
    call 139636653423200
L112:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rsp], r10
# put_cons_ss
    mov qword ptr [r15], 2031
    mov rdi, qword ptr [rbx+40]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# line_I
# i_call_ext_e
L113:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L114
    mov ecx, 1
    call 139636653423200
L114:
# put_cons_ss
    mov qword ptr [r15], 1471
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 447
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 125707
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp get_valid_escape_key/2
# label_L
label_12:
# test_heap_It
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L115
    mov ecx, 6
.db 0x90
    call 139636653423200
L115:
# put_cons_ss
    mov qword ptr [r15], 959
    mov rdi, qword ptr [rbx+40]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 583115
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_13:
# is_in_range_ffScc
    mov rdi, qword ptr [rbx+16]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L117
    cmp rdi, 783
    jl label_16
    cmp rdi, 927
    jg label_15
    short jmp L116
L117:
    mov esi, 783
    mov edx, 927
    call L118
    jl label_16
    jg label_15
L116:
# label_L
label_14:
# test_heap_It
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L119
    mov ecx, 6
.db 0x90
    call 139636653423200
L119:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx+40]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 583115
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_15:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 1759
    jne label_16
# allocate_heap_tIt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L120
    mov ecx, 6
.db 0x66, 0x90
    call 139636653423200
L120:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rsp], r10
# put_cons_ss
    mov qword ptr [r15], 1759
    mov rdi, qword ptr [rbx+40]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# line_I
# i_call_ext_e
L121:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+112]
    cmp rdx, rsp
    short jbe L122
    mov ecx, 1
    call 139636653423200
L122:
# put_cons_ss
    mov qword ptr [r15], 1471
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 447
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_cons_ss
    mov qword ptr [r15], 1759
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+8], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 22795
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L123
    ret
# label_L
label_16:
# is_in_range_ffScc
    mov rdi, qword ptr [rbx+16]
# simplified small & range tests since failure labels are equal
    mov rax, rdi
    sub rax, 543
    test al, 15
    jne L125
    cmp rax, 1488
    ja label_59
    short jmp L124
L125:
    mov esi, 543
    mov edx, 2031
    call L118
    jne label_59
L124:
# allocate_heap_tIt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L126
    mov ecx, 6
.db 0x66, 0x90
    call 139636653423200
L126:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rsp], r10
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rbx+40]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# line_I
# i_call_ext_e
L127:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L128
    mov ecx, 1
    call 139636653423200
L128:
# put_cons_ss
    mov qword ptr [r15], 1471
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 447
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 125707
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp get_valid_escape_key/2
# label_L
label_17:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 1291
    je label_18
    cmp rsi, 26827
    je label_33
    cmp rsi, 583179
    je label_31
    cmp rsi, 583243
    je label_27
    cmp rsi, 583307
    je label_24
    cmp rsi, 583371
    je label_22
    jmp label_57
# label_L
label_18:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 447
    jne label_19
# i_move_sd
    mov qword ptr [rbx+8], 26827
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_19:
# is_ge_lt_ffScc
    mov esi, 15
    mov edx, 511
    mov rdi, qword ptr [rbx+16]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L129
    cmp rdi, rsi
    jl label_21
    cmp rdx, rdi
    jge label_20
    short jmp L130
L129:
    call L105
    jl label_21
    jg label_20
L130:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 2047
    jne label_21
# label_L
label_20:
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L131
    mov ecx, 4
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L131:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
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
    mov qword ptr [r15+8], 579211
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx+24]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L123
    ret
# label_L
label_21:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L132
    mov ecx, 4
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L132:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 59979
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rbx+16]
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L123
    ret
# label_L
label_22:
# is_in_range_ffScc
    mov rdi, qword ptr [rbx+16]
# simplified small & range tests since failure labels are equal
    mov rax, rdi
    sub rax, 543
    test al, 15
    jne L134
    cmp rax, 1488
    ja label_23
    short jmp L133
L134:
    mov esi, 543
    mov edx, 2031
    call L118
    jne label_23
L133:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L135
    mov ecx, 4
.db 0x90
    call 139636653423200
L135:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 1279
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov qword ptr [r15+32], 447
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 125707
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_23:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L136
    mov ecx, 4
    call 139636653423200
L136:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 1279
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov qword ptr [r15+32], 447
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 22795
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_24:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 1471
    jne label_25
# i_move_sd
    mov qword ptr [rbx+8], 583179
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_25:
# is_in_range_ffScc
    mov rdi, qword ptr [rbx+16]
# simplified small & range tests since failure labels are equal
    mov rax, rdi
    sub rax, 543
    test al, 15
    jne L138
    cmp rax, 1488
    ja label_26
    short jmp L137
L138:
    mov esi, 543
    mov edx, 2031
    call L118
    jne label_26
L137:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L139
    mov ecx, 4
.db 0x66, 0x90
    call 139636653423200
L139:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 447
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov qword ptr [r15+32], 447
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 125707
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_26:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L140
    mov ecx, 4
    call 139636653423200
L140:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 447
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov qword ptr [r15+32], 447
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 22795
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_27:
# is_in_range_ffScc
    mov rdi, qword ptr [rbx+16]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L142
    cmp rdi, 783
    jl label_32
    cmp rdi, 927
    jg label_28
    short jmp L141
L142:
    mov esi, 783
    mov edx, 927
    call L118
    jl label_32
    jg label_28
L141:
# test_heap_It
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L143
    mov ecx, 4
.db 0x90
    call 139636653423200
L143:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 583115
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_28:
# is_in_range_ffScc
    mov rdi, qword ptr [rbx+16]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L145
    cmp rdi, 1567
    jl label_29
    cmp rdi, 1967
    jg label_32
    short jmp L144
L145:
    mov esi, 1567
    mov edx, 1967
    call L118
    jl label_29
    jg label_32
L144:
# jump_f
    jmp label_30
# label_L
label_29:
# is_in_range_ffScc
    mov rdi, qword ptr [rbx+16]
# simplified small test since all other types are boxed
    rex test dil, 1
    short je L147
# simplified range test since failure labels are equal
    sub rdi, 1055
    cmp rdi, 400
    ja label_32
    short jmp L146
L147:
    mov esi, 1055
    mov edx, 1455
    call L118
    jne label_32
L146:
# label_L
label_30:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L148
    mov ecx, 4
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L148:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 1471
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov qword ptr [r15+32], 447
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 125707
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_31:
# is_in_range_ffScc
    mov rdi, qword ptr [rbx+16]
# simplified small & range tests since failure labels are equal
    mov rax, rdi
    sub rax, 543
    test al, 15
    jne L150
    cmp rax, 1488
    ja label_32
    short jmp L149
L150:
    mov esi, 543
    mov edx, 2031
    call L118
    jne label_32
L149:
# test_heap_It
    lea rdx, qword ptr [r15+120]
    cmp rdx, rsp
    short jbe L151
    mov ecx, 4
    call 139636653423200
L151:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 1471
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov qword ptr [r15+32], 447
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# append_cons_Is
    mov qword ptr [r15+48], 447
    mov qword ptr [r15+56], rsi
    lea rsi, qword ptr [r15+49]
# store_cons_Id
    add r15, 64
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 125707
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_32:
# test_heap_It
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L152
    mov ecx, 4
    call 139636653423200
L152:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 1471
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov qword ptr [r15+32], 447
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 22795
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_33:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+16]
    cmp rsi, 447
    je label_36
    cmp rsi, 1279
    je label_35
    cmp rsi, 1471
    je label_34
    jmp label_37
# label_L
label_34:
# i_move_sd
    mov qword ptr [rbx+8], 583243
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_35:
# i_move_sd
    mov qword ptr [rbx+8], 583371
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_36:
# i_move_sd
    mov qword ptr [rbx+8], 583307
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_37:
# is_in_range_ffScc
    mov rdi, qword ptr [rbx+16]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L154
    cmp rdi, 543
    jl label_38
    cmp rdi, 2031
    jg label_39
    short jmp L153
L154:
    mov esi, 543
    mov edx, 2031
    call L118
    jl label_38
    jg label_39
L153:
# jump_f
    jmp label_40
# label_L
label_38:
# is_ge_lt_ffScc
    mov esi, 15
    mov edx, 511
    mov rdi, qword ptr [rbx+16]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L155
    cmp rdi, rsi
    jl label_41
    cmp rdx, rdi
    jge label_40
    short jmp L156
L155:
    call L105
    jl label_41
    jg label_40
L156:
# label_L
label_39:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+16], 2047
    jne label_41
# label_L
label_40:
# test_heap_It
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L157
    mov ecx, 4
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L157:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 447
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 125707
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_41:
# test_heap_It
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L158
    mov ecx, 4
    call 139636653423200
L158:
# put_cons_ss
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 447
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 22795
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx+24]
    mov qword ptr [rbx], r11
# i_call_only_f
    jmp get_valid_escape_key/2
# label_L
label_42:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_57
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    jne label_43
    cmp dword ptr [rsi-2], 128
    jne label_43
    cmp qword ptr [rsi+6], 583115
    jne label_43
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_nonempty_list_get_tl_fSd
# simplified fetching of BEAM register
    mov rax, r10
    test al, 2
    jne label_43
    mov rsi, qword ptr [rax+7]
    mov qword ptr [rbx+16], rsi
# is_nil_fS
    cmp byte ptr [rbx+16], 59
    jne label_43
# test_heap_It
    lea rdx, qword ptr [r15+96]
    cmp rdx, rsp
    short jbe L159
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L159:
# put_cons_ss
    mov qword ptr [r15], 1471
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 447
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 579211
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], 59
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L123
    ret
# label_L
label_43:
# i_is_tuple_fs
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    jne label_51
    test byte ptr [rsi-2], 63
    jne label_51
# i_select_tuple_arity_SfI
# skipped fetching of BEAM register
# skipped box test since argument is always boxed
    mov esi, dword ptr [rsi-2]
# simplified tuple test since the source is always a tuple when boxed
    cmp esi, 128
    je label_47
    cmp esi, 192
    je label_44
    jne label_62
# label_L
label_44:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx], r10
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+14], 1
    vmovups xmmword ptr [rbx+8], xmm0
# i_select_val_lins_sfI
# simplified fetching of BEAM register
    mov rsi, r10
    cmp rsi, 22795
    je label_45
    cmp rsi, 125707
    je label_46
    jmp label_60
# label_L
label_45:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L160
    mov ecx, 3
.db 0x66, 0x90
    call 139636653423200
L160:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 22795
# (moving and swapping two elements at once)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L123
    ret
# label_L
label_46:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L161
    mov ecx, 3
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L161:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 579211
# (moving and swapping two elements at once)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L123
    ret
# label_L
label_47:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+6]
    vmovups xmmword ptr [rbx], xmm0
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 22795
    je label_48
    cmp rsi, 125707
    je label_49
    cmp rsi, 583115
    je label_50
    jmp label_61
# label_L
label_48:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L162
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L162:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 22795
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], 59
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L123
    ret
# label_L
label_49:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L163
    mov ecx, 2
    call 139636653423200
L163:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 579211
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], 59
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L123
    ret
# label_L
label_50:
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L164
    mov ecx, 2
    call 139636653423200
L164:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 583115
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 83019
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# return
    dec r14d
    jl L123
    ret
# label_L
label_51:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 26827
    je label_56
    cmp rsi, 583179
    je label_55
    cmp rsi, 583243
    je label_54
    cmp rsi, 583307
    je label_53
    cmp rsi, 583371
    je label_52
    jmp label_62
# label_L
label_52:
# i_move_sd
L165:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# return
    dec r14d
    jl L123
    ret
# label_L
label_53:
# i_move_sd
L166:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# return
    dec r14d
    jl L123
    ret
# label_L
label_54:
# i_move_sd
L167:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# return
    dec r14d
    jl L123
    ret
# label_L
label_55:
# i_move_sd
L168:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# return
    dec r14d
    jl L123
    ret
# label_L
label_56:
# i_move_sd
L169:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# return
    dec r14d
    jl L123
    ret
# label_L
label_57:
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    jne label_58
    cmp dword ptr [rsi-2], 128
    jne label_58
    cmp qword ptr [rsi+6], 22795
    jne label_58
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L170
    mov ecx, 2
.db 0x90
    call 139636653423200
L170:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 22795
# (moving and swapping two elements at once)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r11
# return
    dec r14d
    jl L123
    ret
# label_L
label_58:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L171
    mov ecx, 2
    call 139636653423200
L171:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 22795
# (moving and swapping two elements at once)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [r15+16], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L123
    ret
# label_L
label_59:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L172
# label_L
label_60:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L172
# label_L
label_61:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L172
# label_L
label_62:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L172
# i_func_label_L
    nop
    align 8
label_63:
# func_line_I
# i_func_info_IaaI
# edlin_key:merge/1
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x07, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
merge/1:
# i_breakpoint_trampoline
    short jmp L173
.db 0x90
    call L92
L173:
# i_test_yield
    lea rdx, qword ptr [merge/1+24]
    dec r14d
    long jle L93
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L174
    mov ecx, 1
    call 139636653423200
L174:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# i_call_f
    call key_map/0
# i_move_sd
L175:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp merge/3
# i_func_label_L
    align 8
label_65:
# func_line_I
# i_func_info_IaaI
# edlin_key:merge/3
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x07, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
merge/3:
# i_breakpoint_trampoline
    short jmp L176
.db 0x90
    call L92
L176:
# i_test_yield
    lea rdx, qword ptr [merge/3+24]
    dec r14d
    long jle L93
    align 4
# is_nonempty_list_fS
    test byte ptr [rbx+8], 2
    jne label_70
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L177
    mov ecx, 3
.db 0x66, 0x90
    call 139636653423200
L177:
# get_list_Sdd
    mov rdi, qword ptr [rbx+8]
    mov rsi, qword ptr [rdi-1]
    mov rdx, qword ptr [rdi+7]
    mov qword ptr [rbx+24], rsi
    mov qword ptr [rbx+8], rdx
# i_move_sd
L178:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+32], rdi
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_69
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_69
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L179
    mov ecx, 5
    call 139636653423200
L179:
    sub rsp, 32
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rsp], r10
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx+8]
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+24], r11
# i_get_map_element_fSSS
# simplified fetching of BEAM register
    mov rdi, r11
# simplified fetching of BEAM register
    mov rsi, r10
    call L180
    jne label_67
    mov qword ptr [rbx+8], rax
# jump_f
    jmp label_68
# label_L
label_67:
# i_move_sd
L181:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# label_L
label_68:
# i_move_sd
    mov r10, qword ptr [rbx+32]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L182:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# line_I
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# bif_map_get_jssd
    mov rdi, qword ptr [rsp+16]
    mov rsi, qword ptr [rsp]
# skipped test for map for known map argument
    call L180
    je L183
    mov rdi, qword ptr [rsp+16]
    mov rsi, qword ptr [rsp]
.db 0x66, 0x90
    call 139636653423920
L183:
    mov qword ptr [rbx], rax
# call_light_bif_be
    align 4
L184:
L185:
    long mov rcx, 9223372036854775807
    mov rax, 94068437325200
    lea rdx, qword ptr [L184]
# BIF: maps:merge/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# update_map_assoc_sdtI
    mov rsi, qword ptr [rsp]
    mov rdx, qword ptr [rbx]
    mov rcx, qword ptr [rsp+16]
    call L186
    mov qword ptr [rbx+16], rax
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+24]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 32
    jmp merge/3
# label_L
label_69:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L187
    mov ecx, 1
.db 0x90
    call 139636653423200
L187:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 5387
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
    short jbe L188
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L188:
# call_light_bif_be
    align 4
L189:
L190:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L189]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_70:
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L123
    ret
# i_func_label_L
    align 8
label_71:
# func_line_I
# i_func_info_IaaI
# edlin_key:key_map/0
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0xD5, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
key_map/0:
# i_breakpoint_trampoline
    short jmp L191
.db 0x90
    call L92
L191:
# i_test_yield
    lea rdx, qword ptr [key_map/0+24]
    dec r14d
    long jle L93
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L192
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L192:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call normal_map/0
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+96]
    cmp rdx, rsp
    short jbe L193
    mov ecx, 1
    call 139636653423200
L193:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 4
L194:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
L195:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+32], rdi
L196:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+40], rdi
L197:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+48], rdi
    lea rdi, byte ptr [r15+2]
    add r15, 56
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L123
    ret
# i_func_label_L
    align 8
label_73:
# func_line_I
# i_func_info_IaaI
# edlin_key:normal_map/0
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xE7, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
normal_map/0:
# i_breakpoint_trampoline
    short jmp L198
.db 0x90
    call L92
L198:
# i_test_yield
    lea rdx, qword ptr [normal_map/0+24]
    dec r14d
    long jle L93
    align 4
# i_move_sd
L199:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# return
    dec r14d
    jl L123
    ret
# i_func_label_L
    align 8
label_75:
# func_line_I
# i_func_info_IaaI
# edlin_key:valid_functions/0
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xE7, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
valid_functions/0:
# i_breakpoint_trampoline
    short jmp L200
.db 0x90
    call L92
L200:
# i_test_yield
    lea rdx, qword ptr [valid_functions/0+24]
    dec r14d
    long jle L93
    align 4
# i_move_sd
L201:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# return
    dec r14d
    jl L123
    ret
# i_func_label_L
    align 8
label_77:
# func_line_I
# i_func_info_IaaI
# edlin_key:module_info/0
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L202
.db 0x90
    call L92
L202:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L93
    align 4
# i_move_sd
    mov qword ptr [rbx], 210379
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L203
    mov ecx, 1
.db 0x90
    call 139636653423200
L203:
# call_light_bif_be
    align 4
L204:
L205:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L204]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L123
    ret
# i_func_label_L
    align 8
label_79:
# func_line_I
# i_func_info_IaaI
# edlin_key:module_info/1
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L206
.db 0x90
    call L92
L206:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L93
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 210379
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L207
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L207:
# call_light_bif_be
    align 4
L208:
L209:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L208]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L123
    ret
# i_func_label_L
    align 8
label_81:
# func_line_I
# i_func_info_IaaI
# edlin_key:'-merge/3-fun-0-'/2
    call L90
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x35, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0xE7, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-merge/3-fun-0-'/2:
# i_breakpoint_trampoline
    short jmp L210
.db 0x90
    call L92
L210:
# i_test_yield
    lea rdx, qword ptr ['-merge/3-fun-0-'/2+24]
    dec r14d
    long jle L93
    align 4
# is_list_fs
    mov rax, qword ptr [rbx]
    cmp rax, 59
    short je L211
    test al, 2
    jne label_86
L211:
# is_atom_fs
    mov rax, qword ptr [rbx+8]
    and al, 63
    cmp al, 11
    jne label_86
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L212
    mov ecx, 2
.db 0x90
    call 139636653423200
L212:
    sub rsp, 24
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [rsp], xmm0
# catch_yf
    inc qword ptr [r13+256]
L213:
    mov eax, 2147483647
    mov qword ptr [rsp+16], rax
# i_move_sd
    mov qword ptr [rbx+8], 1291
# line_I
# i_call_f
.db 0x90
    call get_valid_escape_key/2
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
# skipped box test since argument is always boxed
    cmp dword ptr [rsi-2], 192
    jne label_89
    cmp qword ptr [rsi+6], 579211
    jne label_89
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
    mov qword ptr [rbx+8], r10
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    jne label_89
# load_tuple_ptr_s
# skipped fetching of BEAM register
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r11
# is_eq_exact_fss
    mov rsi, qword ptr [rsp]
# simplified fetching of BEAM register
    mov rdi, r11
    cmp rdi, rsi
    short je L214
    mov eax, edi
    or eax, esi
    test al, 2
    jne label_89
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_89
L214:
# line_I
# i_call_f
    call valid_functions/0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# call_light_bif_be
    align 4
L215:
L216:
    long mov rcx, 9223372036854775807
    mov rax, 94068435892832
    lea rdx, qword ptr [L215]
# BIF: lists:member/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_83
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L217
    xor ecx, ecx
.db 0x90
    call 139636653423200
L217:
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
# jump_f
    jmp label_84
# label_L
label_83:
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L218
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L218:
# put_cons_ss
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# append_cons_Is
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+16], rsi
# i_move_sd
L219:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 95051
# line_I
# i_call_ext_e
L220:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx], 11
# label_L
label_84:
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 24
# return
    dec r14d
    jl L123
    ret
# label_L
label_85:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L221
    xor ecx, ecx
.db 0x90
    call 139636653423200
L221:
# put_cons_ss
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# append_cons_Is
# skipped fetching of BEAM register
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+16], rsi
# i_move_sd
L222:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_trim_t
    add rsp, 24
# i_move_sd
    mov qword ptr [rbx], 95051
# line_I
# i_call_ext_e
L223:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx], 11
# deallocate_t
# return
    dec r14d
    jl L123
    ret
# label_L
label_86:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 11723
    jne label_88
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L224
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L224:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call valid_functions/0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
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
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_87
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L227
    xor ecx, ecx
.db 0x90
    call 139636653423200
L227:
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
    jl L123
    ret
# label_L
label_87:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L228
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L228:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# append_cons_Is
# skipped fetching of BEAM register
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+16], rsi
# i_move_sd
L229:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_trim_t
    add rsp, 8
# i_move_sd
    mov qword ptr [rbx], 95051
# line_I
# i_call_ext_e
L230:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx], 11
# deallocate_t
# return
    dec r14d
    jl L123
    ret
# label_L
label_88:
# allocate_heap_tIt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L231
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L231:
# put_cons_ss
    mov rdi, qword ptr [rbx+8]
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
L232:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 95051
# line_I
# i_call_ext_e
L233:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx], 11
# deallocate_t
# return
    dec r14d
    jl L123
    ret
# label_L
label_89:
# line_I
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L172
# int_code_end
L234:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L172:
    jmp 139636653427776
L123:
    jmp 139636653422960
L118:
    jmp 139636653426504
L105:
    jmp 139636653426648
L180:
    jmp 139636653424896
L93:
    jmp 139636653426040
L186:
    jmp 139636653428344
L92:
    jmp 139636653424496
L90:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0x59, 0x14, 0xC9, 0x10, 0xDB, 0xED, 0x46, 0x42, 0x50, 0x9D, 0x55, 0x84, 0x58, 0xFC, 0x19, 0xA4, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x07, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x73, 0x74, 0x64, 0x6C, 0x69, 0x62, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x32, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x73, 0x74, 0x64, 0x6C, 0x69, 0x62, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x2E, 0x2E, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x2B, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x73, 0x74, 0x64, 0x6C, 0x69, 0x62, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x65, 0x64, 0x6C, 0x69, 0x6E, 0x5F, 0x6B, 0x65, 0x79, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0xA4, 0x19, 0xFC, 0x58, 0x84, 0x55, 0x9D, 0x50, 0x42, 0x46, 0xED, 0xDB, 0x10, 0xC9, 0x14, 0x59
.section .text {#0}
