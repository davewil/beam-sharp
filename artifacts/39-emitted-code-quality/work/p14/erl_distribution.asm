    align 8
L30:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# erl_distribution:start_link/0
    call L31
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x22, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x42, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_link/0:
# i_breakpoint_trampoline
    short jmp L32
.db 0x90
    call L33
L32:
# i_test_yield
    lea rdx, qword ptr [start_link/0+24]
    dec r14d
    long jle L34
    align 4
# i_move_sd
L35:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_call_only_f
    jmp do_start_link/1
# i_func_label_L
    align 8
label_3:
# func_line_I
# i_func_info_IaaI
# erl_distribution:start/1
    call L31
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x22, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0xA7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start/1:
# i_breakpoint_trampoline
    short jmp L36
.db 0x90
    call L33
L36:
# i_test_yield
    lea rdx, qword ptr [start/1+24]
    dec r14d
    long jle L34
    align 4
# is_map_fs
    mov rdi, qword ptr [rbx]
    rex test dil, 1
    jne label_5
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 44
    jne label_5
# update_map_assoc_sdtI
.section .rodata {#1}
L37:
    align 8
.db 0x4B, 0x20, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x4B, 0x82, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x4B, 0x43, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00
    align 8
.db 0x0B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
# skipped fetching of BEAM register
    mov qword ptr [rbx+8], rdi
    mov edx, 1
    mov ecx, 4
    lea r8, qword ptr [L37]
.db 0x0F, 0x1F, 0x00
    call 139636653428168
    mov qword ptr [rbx], rax
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L38
    mov ecx, 1
.db 0x90
    call 139636653423200
L38:
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
    mov qword ptr [r15+8], 205515
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
    short jbe L39
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L39:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 6
L40:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], 557643
    mov qword ptr [r15+32], 34187
    mov qword ptr [r15+40], 16015
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+48], rdi
    mov qword ptr [r15+56], 204875
L41:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+64], rdi
    lea rdi, byte ptr [r15+2]
    add r15, 72
    mov qword ptr [rbx+8], rdi
# i_move_sd
    mov qword ptr [rbx], 214091
# i_call_ext_only_e
L42:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_5:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L43
    mov ecx, 1
.db 0x90
    call 139636653423200
L43:
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
    short jbe L44
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L44:
# call_light_bif_be
    align 4
L45:
L46:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L45]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_6:
# func_line_I
# i_func_info_IaaI
# erl_distribution:stop/0
    call L31
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x22, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xA8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
stop/0:
# i_breakpoint_trampoline
    short jmp L47
.db 0x90
    call L33
L47:
# i_test_yield
    lea rdx, qword ptr [stop/0+24]
    dec r14d
    long jle L34
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L48
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L48:
    sub rsp, 8
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov qword ptr [rbx+8], 557643
# i_move_sd
    mov qword ptr [rbx], 214091
# line_I
# i_call_ext_e
L49:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 32075
    jne label_8
# i_move_sd
    mov qword ptr [rbx+8], 557643
# i_move_sd
    mov qword ptr [rbx], 214091
# i_call_ext_last_et
    add rsp, 8
L50:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# label_L
label_8:
# i_move_sd
    mov qword ptr [rbx], 214155
# line_I
# call_light_bif_be
    align 4
L51:
L52:
    long mov rcx, 9223372036854775807
    mov rax, 94068436094864
    lea rdx, qword ptr [L51]
# BIF: erlang:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_pid_fs
    mov rdi, qword ptr [rbx]
    mov eax, edi
    and al, 15
    cmp al, 3
    short je L53
    test al, 1
    jne label_9
    mov eax, dword ptr [rdi-2]
    and al, 63
    cmp al, 48
    jne label_9
L53:
# i_move_sd
L54:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L55
    ret
# label_L
label_9:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L55
    ret
# i_func_label_L
    align 8
label_10:
# func_line_I
# i_func_info_IaaI
# erl_distribution:start_link/1
    call L31
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x22, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x42, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
start_link/1:
# i_breakpoint_trampoline
    short jmp L56
.db 0x90
    call L33
L56:
# i_test_yield
    lea rdx, qword ptr [start_link/1+24]
    dec r14d
    long jle L34
    align 4
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L57
    mov ecx, 1
    call 139636653423200
L57:
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+16], rsi
# i_move_sd
    mov qword ptr [rbx+8], 205515
# i_move_sd
L58:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_call_ext_only_e
L59:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_12:
# func_line_I
# i_func_info_IaaI
# erl_distribution:init/1
    call L31
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x22, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
init/1:
# i_breakpoint_trampoline
    short jmp L60
.db 0x90
    call L33
L60:
# i_test_yield
    lea rdx, qword ptr [init/1+24]
    dec r14d
    long jle L34
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
    mov qword ptr [rbx], 557707
# line_I
# i_call_ext_e
L62:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# is_eq_exact_fss
L64:
    long mov rsi, 9223372036854775807
    mov rdi, qword ptr [rbx]
    cmp rdi, rsi
    short je L63
    rex test dil, 1
    jne label_14
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068436046416
    mov rsp, rbp
    test eax, eax
    je label_14
L63:
# i_move_sd
    mov qword ptr [rsp], 59
# jump_f
    jmp label_15
# label_L
label_14:
# line_I
# i_call_ext_e
L65:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L66
    mov ecx, 1
    call 139636653423200
L66:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    mov qword ptr [r15+16], 213707
    mov qword ptr [r15+24], 59
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx+8], r10
# put_cons_ss
# skipped fetching of BEAM register
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+16], rsi
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+112]
    cmp rdx, rsp
    short jbe L67
    mov ecx, 3
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L67:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 6
L68:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
    mov qword ptr [r15+32], 34187
    mov qword ptr [r15+40], 32015
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+48], rdi
    mov qword ptr [r15+56], 269259
    mov rdi, qword ptr [rbx+16]
    mov qword ptr [r15+64], rdi
    lea rdi, byte ptr [r15+2]
    add r15, 72
    mov qword ptr [rbx], rdi
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L69
    mov ecx, 1
.db 0x90
    call 139636653423200
L69:
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rsp], rsi
# label_L
label_15:
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L70
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L70:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 192
# Move tuple data
    mov qword ptr [r15+8], 29067
    mov qword ptr [r15+16], 213707
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+24], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 32
    mov qword ptr [rbx], r10
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+112]
    cmp rdx, rsp
    short jbe L71
    mov ecx, 1
.db 0x90
    call 139636653423200
L71:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 6
L72:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], 29067
    mov qword ptr [r15+32], 34187
    mov qword ptr [r15+40], 32015
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+48], rdi
    mov qword ptr [r15+56], 269259
L73:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+64], rdi
    lea rdi, byte ptr [r15+2]
    add r15, 72
    mov qword ptr [rsp+8], rdi
# line_I
# i_call_ext_e
L74:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L75
    mov ecx, 1
    call 139636653423200
L75:
# put_cons_ss
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# append_cons_Is
L76:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov qword ptr [r15+24], rsi
    lea rsi, qword ptr [r15+17]
# store_cons_Id
    add r15, 32
    mov qword ptr [rbx+8], rsi
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_trim_t
    add rsp, 8
# line_I
# call_light_bif_be
    align 4
L77:
L78:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L77]
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
L79:
L80:
    long mov rcx, 9223372036854775807
    mov rax, 94068435890976
    lea rdx, qword ptr [L79]
# BIF: erlang:'++'/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L81
    mov ecx, 1
    call 139636653423200
L81:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
L82:
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
    jl L55
    ret
# i_func_label_L
    align 8
label_16:
# func_line_I
# i_func_info_IaaI
# erl_distribution:do_start_link/1
    call L31
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x22, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x82, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
do_start_link/1:
# i_breakpoint_trampoline
    short jmp L83
.db 0x90
    call L33
L83:
# i_test_yield
    lea rdx, qword ptr [do_start_link/1+24]
    dec r14d
    long jle L34
    align 4
# is_nonempty_list_fS
    test byte ptr [rbx], 2
    jne label_24
# allocate_tt
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L84
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L84:
    sub rsp, 40
# init_yregs_I
    mov eax, 59
    mov rdi, rsp
    stos qword ptr [rdi], rax
    stos qword ptr [rdi], rax
# get_list_Sdd
    mov rdi, qword ptr [rbx]
    mov rsi, qword ptr [rdi-1]
    mov rdx, qword ptr [rdi+7]
    mov qword ptr [rbx], rsi
    mov qword ptr [rsp+32], rdx
# load_tuple_ptr_s
# skipped fetching of BEAM register
# get_two_tuple_elements_sPSS
    vpermilpd xmm0, xmmword ptr [rsi+6], 1
    vmovups xmmword ptr [rsp+16], xmm0
# i_move_sd
    mov r10, qword ptr [rsp+24]
    mov qword ptr [rbx], r10
# line_I
# i_call_ext_e
L85:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_is_tagged_tuple_fsAa
    mov rsi, qword ptr [rbx]
    rex test sil, 1
    jne label_23
    cmp dword ptr [rsi-2], 128
    jne label_23
    cmp qword ptr [rsi+6], 32075
    jne label_23
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx], r10
# is_nonempty_list_get_list_fSdd
# simplified fetching of BEAM register
    mov rax, r10
    test al, 2
    jne label_23
    mov rsi, qword ptr [rax-1]
    mov rdx, qword ptr [rax+7]
    mov qword ptr [rsp+8], rsi
    mov qword ptr [rbx], rdx
# is_nonempty_list_get_list_fSdd
# simplified fetching of BEAM register
    mov rax, rsi
    test al, 2
    jne label_21
    mov rsi, qword ptr [rax-1]
    mov rdx, qword ptr [rax+7]
    mov qword ptr [rsp], rsi
    mov qword ptr [rbx+8], rdx
# is_nil_fS
    cmp byte ptr [rbx+8], 59
    jne label_21
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_18
# i_move_sd
# skipped fetching of BEAM register
    mov qword ptr [rbx], rsi
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rsp+32], r10
# i_trim_t
    add rsp, 32
# line_I
# call_light_bif_be
    align 4
L86:
L87:
    long mov rcx, 9223372036854775807
    mov rax, 94068436101856
    lea rdx, qword ptr [L86]
# BIF: erlang:list_to_atom/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+96]
    cmp rdx, rsp
    short jbe L88
    mov ecx, 1
    call 139636653423200
L88:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 4
L89:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
    mov qword ptr [r15+32], 214155
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+40], rdi
    mov qword ptr [r15+48], 75
    lea rdi, byte ptr [r15+2]
    add r15, 56
    mov qword ptr [rbx], rdi
# i_call_last_ft
    add rsp, 8
    jmp start_link/1
# label_L
label_18:
# i_move_sd
    mov qword ptr [rbx+8], 205515
# init_yregs_I
    mov qword ptr [rsp+32], 59
# i_move_sd
    mov qword ptr [rbx], 47563
# line_I
# i_call_ext_e
L90:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_20
    cmp rsi, 75
    je label_19
    jmp label_25
# label_L
label_19:
# test_heap_It
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L91
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L91:
# put_cons_ss
    mov rdi, qword ptr [rsp+24]
    mov qword ptr [r15], rdi
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+8], rdi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
    mov qword ptr [rbx+8], 47563
# i_move_sd
L92:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# init_yregs_I
    mov eax, 59
    mov qword ptr [rsp+8], rax
    mov qword ptr [rsp+24], rax
# i_move_sd
L93:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# i_call_ext_e
L94:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# label_L
label_20:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 16
# line_I
# call_light_bif_be
    align 4
L95:
L96:
    long mov rcx, 9223372036854775807
    mov rax, 94068436101856
    lea rdx, qword ptr [L95]
# BIF: erlang:list_to_atom/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_new_small_map_lit_dtqI
    lea rdx, qword ptr [r15+96]
    cmp rdx, rsp
    short jbe L97
    mov ecx, 1
    call 139636653423200
L97:
    mov qword ptr [r15], 300
    mov qword ptr [r15+8], 4
L98:
    long mov rdi, 9223372036854775807
    mov qword ptr [r15+16], rdi
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+24], rdi
    mov qword ptr [r15+32], 214155
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+40], rdi
    mov qword ptr [r15+48], 75
    lea rdi, byte ptr [r15+2]
    add r15, 56
    mov qword ptr [rbx], rdi
# i_call_last_ft
    add rsp, 24
    jmp start_link/1
# label_L
label_21:
# i_move_sd
    mov qword ptr [rbx+8], 205515
# init_yregs_I
    mov qword ptr [rsp+16], 59
# i_move_sd
    mov qword ptr [rbx], 779
# line_I
# i_call_ext_e
L99:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 11
    je label_23
    cmp rsi, 75
    je label_22
    jmp label_26
# label_L
label_22:
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# init_yregs_I
    mov qword ptr [rsp+8], 59
# i_move_sd
L100:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L101:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x0F, 0x1F, 0x00
    call qword ptr [rax+r12*8]
# test_heap_It
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L102
    mov ecx, 1
    call 139636653423200
L102:
# put_cons_ss
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], 59
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# append_cons_Is
    mov rdi, qword ptr [rsp+24]
    mov qword ptr [r15], rdi
    mov qword ptr [r15+8], rsi
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx+24], rsi
# i_move_sd
    mov qword ptr [rbx+8], 779
# i_move_sd
L103:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+16], rdi
# init_yregs_I
    mov qword ptr [rsp+24], 59
# i_move_sd
L104:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# i_call_ext_e
L105:
    long mov rax, 9223372036854775807
    call qword ptr [rax+r12*8]
.db 0x90
    call qword ptr [rax+r12*8]
# label_L
label_23:
# i_move_sd
    mov r10, qword ptr [rsp+32]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 40
    jmp do_start_link/1
# label_L
label_24:
# i_move_sd
    mov qword ptr [rbx], 21515
# return
    dec r14d
    jl L55
    ret
# label_L
label_25:
# line_I
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L106
# label_L
label_26:
# line_I
    nop
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L106
# i_func_label_L
    nop
    align 8
label_27:
# func_line_I
# i_func_info_IaaI
# erl_distribution:module_info/0
    call L31
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x22, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L107
.db 0x90
    call L33
L107:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L34
    align 4
# i_move_sd
    mov qword ptr [rbx], 205515
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L108
    mov ecx, 1
.db 0x90
    call 139636653423200
L108:
# call_light_bif_be
    align 4
L109:
L110:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L109]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L55
    ret
# i_func_label_L
    align 8
label_29:
# func_line_I
# i_func_info_IaaI
# erl_distribution:module_info/1
    call L31
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xCB, 0x22, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L111
.db 0x90
    call L33
L111:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L34
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 205515
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L112
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L112:
# call_light_bif_be
    align 4
L113:
L114:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L113]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L55
    ret
# int_code_end
L115:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L106:
    jmp 139636653427776
L55:
    jmp 139636653422960
L34:
    jmp 139636653426040
L33:
    jmp 139636653424496
L31:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x02, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0x28, 0x37, 0x8F, 0xF3, 0x33, 0x49, 0x43, 0x0E, 0x63, 0xFF, 0xCC, 0xCB, 0xA3, 0x1E, 0x86, 0x5C, 0x6A, 0x68, 0x02, 0x77, 0x09, 0x62, 0x65, 0x68, 0x61, 0x76, 0x69, 0x6F, 0x75, 0x72, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x77, 0x0A, 0x73, 0x75, 0x70, 0x65, 0x72, 0x76, 0x69, 0x73, 0x6F, 0x72, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x32, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x65, 0x72, 0x6C, 0x5F, 0x64, 0x69, 0x73, 0x74, 0x72, 0x69, 0x62, 0x75, 0x74, 0x69, 0x6F, 0x6E, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0x5C, 0x86, 0x1E, 0xA3, 0xCB, 0xCC, 0xFF, 0x63, 0x0E, 0x43, 0x49, 0x33, 0xF3, 0x8F, 0x37, 0x28
.section .text {#0}
