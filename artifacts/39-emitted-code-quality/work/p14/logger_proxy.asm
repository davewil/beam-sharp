    align 8
L56:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# logger_proxy:log/1
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xDD, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
log/1:
# i_breakpoint_trampoline
    short jmp L58
.db 0x90
    call L59
L58:
# i_test_yield
    lea rdx, qword ptr [log/1+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L61
    mov ecx, 1
    call 139636653423200
L61:
    sub rsp, 16
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# i_move_sd
    mov qword ptr [rbx+8], 907
# i_move_sd
    mov qword ptr [rbx], 208139
# line_I
# call_light_bif_be
    align 4
L62:
L63:
    long mov rcx, 9223372036854775807
    mov rax, 94068435902592
    lea rdx, qword ptr [L62]
# BIF: persistent_term:get/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# is_ne_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 907
    je label_3
# line_I
# i_call_ext_e
L64:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx+8], r10
# is_eq_exact_fss
# simplified fetching of BEAM register
    mov rsi, r10
    mov rdi, qword ptr [rbx]
    cmp rdi, rsi
    short je L65
    mov eax, edi
    or eax, esi
    test al, 1
    jne label_4
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_4
L65:
# label_L
label_3:
# i_move_sd
    mov qword ptr [rbx+8], 439691
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 16
# line_I
# i_call_f
.db 0x90
    call handle_load/2
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L66
    ret
# label_L
label_4:
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [rbx], xmm0
# line_I
# i_call_ext_last_et
    add rsp, 16
L67:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_5:
# func_line_I
# i_func_info_IaaI
# logger_proxy:start_link/0
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x42, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_link/0:
# i_breakpoint_trampoline
    short jmp L68
.db 0x90
    call L59
L68:
# i_test_yield
    lea rdx, qword ptr [start_link/0+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L69
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L69:
# line_I
# i_call_ext_e
L70:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx+16], 59
# i_move_sd
    mov qword ptr [rbx+8], 208139
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+24], r10
# i_move_sd
    mov qword ptr [rbx], 208139
# i_call_ext_last_et
L71:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_7:
# func_line_I
# i_func_info_IaaI
# logger_proxy:restart/0
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x93, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
restart/0:
# i_breakpoint_trampoline
    short jmp L72
.db 0x90
    call L59
L72:
# i_test_yield
    lea rdx, qword ptr [restart/0+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L73
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L73:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call child_spec/0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 208267
# i_call_ext_e
L74:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# i_select_tuple_arity_SfI
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_11
    mov esi, dword ptr [rsi-2]
    rex test sil, 63
    jne label_11
    cmp esi, 128
    je label_10
    cmp esi, 192
    je label_9
    jne label_11
# label_L
label_9:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 32075
    jne label_11
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L75
    mov ecx, 1
    call 139636653423200
L75:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+22]
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
    jl L66
    ret
# label_L
label_10:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+8], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 779
    jne label_11
# load_tuple_ptr_s
# skipped fetching of BEAM register
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r11
# i_is_tuple_of_arity_fsA
# simplified fetching of BEAM register
    mov rsi, r11
    rex test sil, 1
    jne label_11
    cmp dword ptr [rsi-2], 128
    jne label_11
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+16], r10
# i_is_tuple_fs
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_11
    test byte ptr [rsi-2], 63
    jne label_11
# bif_element_jssd
# simplified fetching of BEAM register
    mov rsi, r10
# skipped tuple test since source is always a tuple
    cmp dword ptr [rsi-2], 64
    jb label_11
    mov rax, qword ptr [rsi+6]
    mov qword ptr [rbx+16], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 231051
    jne label_11
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L76
    mov ecx, 2
.db 0x90
    call 139636653423200
L76:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
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
# return
    dec r14d
    jl L66
    ret
# label_L
label_11:
# deallocate_t
# return
    dec r14d
    jl L66
    ret
# i_func_label_L
    align 8
label_12:
# func_line_I
# i_func_info_IaaI
# logger_proxy:child_spec/0
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0xB5, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
child_spec/0:
# i_breakpoint_trampoline
    short jmp L77
.db 0x90
    call L59
L77:
# i_test_yield
    lea rdx, qword ptr [child_spec/0+24]
    dec r14d
    long jle L60
    align 4
# i_move_sd
L78:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# return
    dec r14d
    jl L66
    ret
# i_func_label_L
    align 8
label_14:
# func_line_I
# i_func_info_IaaI
# logger_proxy:get_default_config/0
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x42, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_default_config/0:
# i_breakpoint_trampoline
    short jmp L79
.db 0x90
    call L59
L79:
# i_test_yield
    lea rdx, qword ptr [get_default_config/0+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L80
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L80:
# line_I
# i_call_ext_e
L81:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_16
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_16
# update_map_assoc_sdtI
.section .rodata {#1}
L82:
    align 8
.db 0x4B, 0xB6, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x0B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x8B, 0xB6, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x8F, 0x3E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0xCB, 0xB6, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x8F, 0x38, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x0B, 0xB7, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x4F, 0x1F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
# skipped fetching of BEAM register
    mov qword ptr [rbx+8], rdi
    mov edx, 1
    mov ecx, 8
    lea r8, qword ptr [L82]
.db 0x0F, 0x1F, 0x00
    call 139636653428168
    mov qword ptr [rbx], rax
# deallocate_t
# return
    dec r14d
    jl L66
    ret
# label_L
label_16:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L83
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L83:
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
# call_light_bif_be
    align 4
L84:
L85:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L84]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_17:
# func_line_I
# i_func_info_IaaI
# logger_proxy:init/1
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
init/1:
# i_breakpoint_trampoline
    short jmp L86
.db 0x90
    call L59
L86:
# i_test_yield
    lea rdx, qword ptr [init/1+24]
    dec r14d
    long jle L60
    align 4
# is_nil_fS
    cmp byte ptr [rbx], 59
    short jne label_17
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L87
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L87:
# i_move_sd
    mov qword ptr [rbx+8], 75
# i_move_sd
    mov qword ptr [rbx], 45387
# line_I
# call_light_bif_be
    align 4
L88:
L89:
    long mov rcx, 9223372036854775807
    mov rax, 94068436092464
    lea rdx, qword ptr [L88]
# BIF: erlang:process_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 440139
# line_I
# call_light_bif_be
    align 4
L90:
L91:
    long mov rcx, 9223372036854775807
    mov rax, 94068436116496
    lea rdx, qword ptr [L90]
# BIF: erlang:system_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# line_I
# i_call_ext_e
L92:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 208139
# call_light_bif_be
    align 4
L93:
L94:
    long mov rcx, 9223372036854775807
    mov rax, 94068435899424
    lea rdx, qword ptr [L93]
# BIF: persistent_term:put/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
L95:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L66
    ret
# i_func_label_L
    align 8
label_19:
# func_line_I
# i_func_info_IaaI
# logger_proxy:handle_load/2
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0xB7, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_load/2:
# i_breakpoint_trampoline
    short jmp L96
.db 0x90
    call L59
L96:
# i_test_yield
    lea rdx, qword ptr [handle_load/2+24]
    dec r14d
    long jle L60
    align 4
# i_select_tuple_arity_SfI
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    short jne label_19
    mov esi, dword ptr [rsi-2]
    rex test sil, 63
    short jne label_19
    cmp esi, 192
    je label_23
    cmp esi, 256
    je label_22
    cmp esi, 320
    je label_21
    short jne label_19
# label_L
label_21:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 56651
    jne label_19
# allocate_heap_tIt
    lea rdx, qword ptr [r15+104]
    cmp rdx, rsp
    short jbe L97
    mov ecx, 2
    call 139636653423200
L97:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rbx+8], xmm0
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+30]
    mov qword ptr [rbx+24], r11
# i_get_tuple_element_sPS
    mov rdx, qword ptr [rsi+38]
    mov qword ptr [rbx], rdx
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, rdx
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
# simplified fetching of BEAM register
    mov rdi, r11
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+32], rdi
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# append_cons_Is
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+48], rdi
    mov qword ptr [r15+56], rsi
    lea rsi, qword ptr [r15+49]
# store_cons_Id
    add r15, 64
    mov qword ptr [rbx], rsi
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call try_log/1
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L66
    ret
# label_L
label_22:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 56651
    jne label_19
# allocate_heap_tIt
    lea rdx, qword ptr [r15+88]
    cmp rdx, rsp
    short jbe L98
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L98:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vmovups xmm0, xmmword ptr [rsi+14]
    vmovups xmmword ptr [rbx+8], xmm0
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+30]
    mov qword ptr [rbx], r11
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, r11
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# append_cons_Is
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+32], rdi
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# line_I
# i_call_f
.db 0x66, 0x90
    call try_log/1
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L66
    ret
# label_L
label_23:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 170827
    jne label_19
# allocate_heap_tIt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L99
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L99:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r11
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 208139
# simplified fetching of BEAM register
    mov rdi, r11
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea rdx, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], rdx
# load_tuple_ptr_s
# skipped fetching of BEAM register
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+22]
    mov qword ptr [rbx], r11
# i_move_sd
L100:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L101:
L102:
    long mov rcx, 9223372036854775807
    mov rax, 94068436095776
    lea rdx, qword ptr [L101]
# BIF: erlang:send/3
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L66
    ret
# i_func_label_L
    align 8
label_24:
# func_line_I
# i_func_info_IaaI
# logger_proxy:handle_info/2
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x5D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
handle_info/2:
# i_breakpoint_trampoline
    short jmp L103
.db 0x90
    call L59
L103:
# i_test_yield
    lea rdx, qword ptr [handle_info/2+24]
    dec r14d
    long jle L60
    align 4
# i_is_tuple_fs
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_26
    test byte ptr [rsi-2], 63
    jne label_26
# bif_element_jssd
# skipped fetching of BEAM register
# skipped tuple test since source is always a tuple
    cmp dword ptr [rsi-2], 64
    jb label_26
    mov rax, qword ptr [rsi+6]
    mov qword ptr [rbx], rax
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp rax, 56651
    jne label_26
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L104
    mov ecx, 2
    call 139636653423200
L104:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 215371
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L66
    ret
# label_L
label_26:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L66
    ret
# i_func_label_L
    align 8
label_27:
# func_line_I
# i_func_info_IaaI
# logger_proxy:terminate/2
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x53, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
terminate/2:
# i_breakpoint_trampoline
    short jmp L105
.db 0x90
    call L59
L105:
# i_test_yield
    lea rdx, qword ptr [terminate/2+24]
    dec r14d
    long jle L60
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 440331
    jne label_29
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L106
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L106:
# i_move_sd
    mov qword ptr [rbx+8], 907
# i_move_sd
    mov qword ptr [rbx], 440139
# line_I
# call_light_bif_be
    align 4
L107:
L108:
    long mov rcx, 9223372036854775807
    mov rax, 94068436116496
    lea rdx, qword ptr [L107]
# BIF: erlang:system_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
L109:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
# return
    dec r14d
    jl L66
    ret
# label_L
label_29:
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L110
    xor ecx, ecx
    call 139636653423200
L110:
# i_move_sd
    mov qword ptr [rbx], 25099
# line_I
# call_light_bif_be
    align 4
L111:
L112:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094864
    lea rdx, qword ptr [L111]
# BIF: erlang:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 440139
# call_light_bif_be
    align 4
L113:
L114:
    long mov rcx, 9223372036854775807
    mov rax, 94068436116496
    lea rdx, qword ptr [L113]
# BIF: erlang:system_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L66
    ret
# i_func_label_L
    align 8
label_30:
# func_line_I
# i_func_info_IaaI
# logger_proxy:notify/2
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x7B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
notify/2:
# i_breakpoint_trampoline
    short jmp L115
.db 0x90
    call L59
L115:
# i_test_yield
    lea rdx, qword ptr [notify/2+24]
    dec r14d
    long jle L60
    align 4
# i_is_tuple_fs
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_40
    test byte ptr [rsi-2], 63
    jne label_40
# i_select_tuple_arity_SfI
# skipped fetching of BEAM register
# skipped box test since argument is always boxed
    mov esi, dword ptr [rsi-2]
# simplified tuple test since the source is always a tuple when boxed
    cmp esi, 128
    je label_37
    cmp esi, 192
    je label_32
    jne label_43
# label_L
label_32:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 440395
    jne label_43
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L116
    mov ecx, 2
    call 139636653423200
L116:
    sub rsp, 24
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+16], r10
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+14], 1
    vmovups xmmword ptr [rsp], xmm0
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rsp], 440459
    jne label_33
# i_move_sd
    mov qword ptr [rbx+8], 907
# i_move_sd
    mov qword ptr [rbx], 440139
# line_I
# call_light_bif_be
    align 4
L117:
L118:
    long mov rcx, 9223372036854775807
    mov rax, 94068436116496
    lea rdx, qword ptr [L117]
# BIF: erlang:system_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# jump_f
    jmp label_34
# label_L
label_33:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rsp+8], 440459
    jne label_34
# self_d
    mov r10, qword ptr [r13]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 440139
# line_I
# call_light_bif_be
    align 4
L119:
L120:
    long mov rcx, 9223372036854775807
    mov rax, 94068436116496
    lea rdx, qword ptr [L119]
# BIF: erlang:system_flag/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# label_L
label_34:
# i_move_sd
    mov qword ptr [rbx+8], 208139
# i_move_sd
    mov qword ptr [rbx], 214667
# line_I
# i_call_ext_e
L121:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_36
    cmp rsi, 75
    je label_35
    jmp label_44
# label_L
label_35:
# test_heap_It
    lea rdx, qword ptr [r15+112]
    cmp rdx, rsp
    short jbe L122
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L122:
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
    mov qword ptr [r15+32], 208139
    mov qword ptr [r15+40], rsi
    lea rsi, qword ptr [r15+33]
# store_cons_Id
    add r15, 48
    mov qword ptr [rbx], rsi
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# append_cons_Is
L123:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
L124:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
L125:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# i_move_sd
    mov qword ptr [rbx], 214667
# i_call_ext_e
L126:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# label_L
label_36:
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 24
# return
    dec r14d
    jl L66
    ret
# label_L
label_37:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx], r11
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 440523
    jne label_43
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L127
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L127:
    sub rsp, 16
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov qword ptr [rbx+8], 208139
# i_move_sd
    mov qword ptr [rbx], 214667
# line_I
# i_call_ext_e
L128:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_39
    cmp rsi, 75
    je label_38
    jmp label_45
# label_L
label_38:
# test_heap_It
    lea rdx, qword ptr [r15+96]
    cmp rdx, rsp
    short jbe L129
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L129:
# put_cons_ss
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
    mov qword ptr [r15+16], 208139
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# append_cons_Is
L130:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
L131:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
L132:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov qword ptr [rbx], 214667
# i_call_ext_e
L133:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# label_L
label_39:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L66
    ret
# label_L
label_40:
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 37707
    jne label_43
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L134
    mov ecx, 2
.db 0x90
    call 139636653423200
L134:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp], r10
# i_move_sd
    mov qword ptr [rbx+8], 208139
# i_move_sd
    mov qword ptr [rbx], 214667
# line_I
# i_call_ext_e
L135:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_42
    cmp rsi, 75
    je label_41
    jmp label_46
# label_L
label_41:
# i_move_sd
L136:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# i_move_sd
L137:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
L138:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+24], rdi
# i_move_sd
    mov qword ptr [rbx], 214667
# i_call_ext_e
L139:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# label_L
label_42:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L66
    ret
# label_L
label_43:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L66
    ret
# label_L
label_44:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L140
# label_L
label_45:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L140
# label_L
label_46:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L140
# i_func_label_L
    nop
    align 8
label_47:
# func_line_I
# i_func_info_IaaI
# logger_proxy:try_log/1
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xB9, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
try_log/1:
# i_breakpoint_trampoline
    short jmp L141
.db 0x90
    call L59
L141:
# i_test_yield
    lea rdx, qword ptr [try_log/1+24]
    dec r14d
    long jle L60
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L142
    mov ecx, 1
    call 139636653423200
L142:
    sub rsp, 32
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# catch_yf
    inc qword ptr [r13+256]
L143:
    mov eax, 2147483647
    mov qword ptr [rsp+24], rax
# i_move_sd
    mov qword ptr [rbx+8], 56651
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+16], r10
# i_move_sd
    mov qword ptr [rbx], 25099
# line_I
# i_apply
    align 4
L145:
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
    short jne L144
    lea rsi, qword ptr [L145]
    mov rcx, 94068445024480
    push rsi
    jmp L146
L144:
    call qword ptr [rax+r12*8]
    call qword ptr [rax+r12*8]
# try_end_deallocate_t
    dec qword ptr [r13+256]
    add rsp, 32
# return
    dec r14d
    jl L66
    ret
# label_L
label_49:
# try_case_y
    dec qword ptr [r13+256]
    mov rax, qword ptr [rbx+24]
    mov qword ptr [rbx], rax
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp+24], r10
# i_move_sd
    mov qword ptr [rbx+8], 208139
# i_move_sd
    mov qword ptr [rbx], 81611
# line_I
# i_call_ext_e
L147:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_51
    cmp rsi, 75
    je label_50
    jmp label_52
# label_L
label_50:
# i_move_sd
    mov r10, qword ptr [rsp+24]
    mov qword ptr [rbx], r10
# build_stacktrace
# simplified fetching of BEAM register
    mov rsi, r10
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435483376
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+176]
    cmp rdx, rsp
    short jbe L148
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L148:
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
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 36747
# simplified fetching of BEAM register
    mov rdi, r10
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, r11
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
    mov qword ptr [r15+8], 56651
    mov rdi, qword ptr [rsp+16]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# put_cons_ss
# (putting and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [r15], xmm0
    lea rsi, qword ptr [r15+1]
# append_cons_Is
L149:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx], rsi
# put_cons_ss
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
L150:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# i_move_sd
L151:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# i_trim_t
    add rsp, 32
# i_move_sd
    mov qword ptr [rbx], 81611
# line_I
# i_call_ext_e
L152:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L66
    ret
# label_L
label_51:
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
    add rsp, 32
# return
    dec r14d
    jl L66
    ret
# label_L
label_52:
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L140
# i_func_label_L
    nop
    align 8
label_53:
# func_line_I
# i_func_info_IaaI
# logger_proxy:module_info/0
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L153
.db 0x90
    call L59
L153:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L60
    align 4
# i_move_sd
    mov qword ptr [rbx], 208139
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L154
    mov ecx, 1
.db 0x90
    call 139636653423200
L154:
# call_light_bif_be
    align 4
L155:
L156:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L155]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L66
    ret
# i_func_label_L
    align 8
label_55:
# func_line_I
# i_func_info_IaaI
# logger_proxy:module_info/1
    call L57
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x0B, 0x2D, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L157
.db 0x90
    call L59
L157:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L60
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 208139
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L158
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L158:
# call_light_bif_be
    align 4
L159:
L160:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L159]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L66
    ret
# int_code_end
L161:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L146:
    jmp 139636653427784
L140:
    jmp 139636653427776
L66:
    jmp 139636653422960
L60:
    jmp 139636653426040
L59:
    jmp 139636653424496
L57:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0xA4, 0x67, 0xFB, 0xF1, 0x82, 0x5B, 0x36, 0xDC, 0x8C, 0x0D, 0x58, 0xB6, 0x66, 0xC7, 0xDD, 0xC5, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x2E, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x6C, 0x6F, 0x67, 0x67, 0x65, 0x72, 0x5F, 0x70, 0x72, 0x6F, 0x78, 0x79, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0xC5, 0xDD, 0xC7, 0x66, 0xB6, 0x58, 0x0D, 0x8C, 0xDC, 0x36, 0x5B, 0x82, 0xF1, 0xFB, 0x67, 0xA4
.section .text {#0}
