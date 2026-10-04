    align 8
global::apply_fun_shared:
    xor edx, edx
    mov rcx, qword ptr [rbx]
    mov r8, qword ptr [rbx+8]
    mov rdi, r8
L98:
    cmp edi, 59
    short je L97
    rex test dil, 2
    short jne L99
    mov rax, qword ptr [rdi-1]
    mov rdi, qword ptr [rdi+7]
    mov qword ptr [rbx+rdx*8], rax
    inc rdx
    cmp rdx, 1023
    short jb L98
    mov rax, 15440
    jmp L100
L99:
    mov rax, 3152
L100:
    mov qword ptr [rbx], rcx
    mov qword ptr [rbx+8], r8
    mov qword ptr [r13+104], rax
    mov rcx, 94068441274896
    jmp global::raise_exception
L97:
    shl rdx, 8
    or rdx, 20
    ret
    align 8
global::arith_compare_shared:
    mov edx, edi
    or edx, esi
    and edx, 1
    short jne L101
    mov rdx, qword ptr [rdi-2]
    mov r8, qword ptr [rsi-2]
    and edx, 63
    and r8d, 63
    sub edx, 24
    sub r8d, 24
    or edx, r8d
    jne L102
    vmovsd xmm0, qword ptr [rdi+6]
    vmovsd xmm1, qword ptr [rsi+6]
    vucomisd xmm0, xmm1
    seta al
    setb ah
    sub al, ah
    ret
L101:
    mov edx, edi
    mov r8d, esi
    and edx, 63
    and r8d, 63
    sub edx, 11
    sub r8d, 11
    or edx, r8d
    jne L102
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068435046912
    mov rsp, rbp
    test eax, eax
    ret
L102:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
# erts_cmp_compound(X, Y, 0, 0);
    xor edx, edx
    xor ecx, ecx
    call 94068436048800
    mov rsp, rbp
    test rax, rax
    ret
    align 8
global::arith_eq_shared:
    mov edx, edi
    or edx, esi
    and edx, 1
    short jne L103
    mov rdx, qword ptr [rdi-2]
    mov r8, qword ptr [rsi-2]
    and edx, 63
    and r8d, 63
    sub edx, 24
    sub r8d, 24
    or edx, r8d
    short jne L103
    vmovsd xmm0, qword ptr [rdi+6]
    vmovsd xmm1, qword ptr [rsi+6]
    vucomisd xmm0, xmm1
    ret
L103:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
# erts_cmp_compound(X, Y, 0, 1);
    xor edx, edx
    mov ecx, 1
    call 94068436048800
    mov rsp, rbp
    test rax, rax
    ret
    align 8
global::bif_nif_epilogue:
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    mov rdi, 94068445118180
    mov edi, dword ptr [rdi]
    cmp r12, 3
    cmovne r12, rdi
    test eax, eax
    short je L104
# Do return and dispatch to it
    mov qword ptr [rbx], rax
    ret
L104:
    cmp qword ptr [r13+104], 1024
    jne L106
# yield
# test trap to hibernate
    mov edi, dword ptr [r13+124]
    mov esi, edi
    and esi, 1
    short je L105
# do hibernate trap
    and edi, -2
    mov dword ptr [r13+124], edi
    jmp global::do_schedule
L105:
# do normal trap
    mov rdx, qword ptr [r13+248]
    jmp global::context_switch_simplified
L106:
    mov rsi, rsp
    mov qword ptr [r13+88], rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435482256
    mov rsp, qword ptr [r13+88]
    mov rsi, rax
    mov rcx, qword ptr [r13+464]
    jmp global::raise_exception_shared
    align 8
global::bif_element_shared:
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L107
    mov rcx, rdi
    sar rcx, 4
    rex test sil, 1
    short jne L107
    mov r8, rsi
    lea r8, qword ptr [r8-2]
    mov r9, qword ptr [r8]
    mov eax, r9d
    and al, 63
    short jne L107
    shr r9, 6
    dec rcx
    cmp r9, rcx
    short jbe L107
    inc rcx
    mov rax, qword ptr [r8+rcx*8]
    ret
L107:
    test rdx, rdx
    je global::handle_element_error
    add rsp, 8
    jmp rdx
    align 8
global::bif_export_trap:
    mov rax, qword ptr [r13+464]
    sub rax, 64
    jmp qword ptr [rax+r12*8]
    align 8
global::bs_create_bin_error_shared:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rcx
    mov rcx, rdi
    mov rdi, r13
    call 94068434773440
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    pop rsi
    and rsi, -8
    push rsi
    xor ecx, ecx
    jmp global::raise_exception_shared
    align 8
global::bs_size_check_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068434772576
    mov rsp, rbp
    ret
    align 8
global::bs_get_tail_shared:
    mov qword ptr [r13+80], r15
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, qword ptr [rdi+30]
    mov rdx, rsi
    and rsi, 7
    and rdx, -8
    mov rcx, qword ptr [rdi+6]
    and rcx, -4
    mov r8, qword ptr [rdi+14]
    mov r9, qword ptr [rdi+22]
    sub r9, r8
    lea rdi, qword ptr [r13+80]
    call 94068436971456
    mov rsp, rbp
    mov r15, qword ptr [r13+80]
    ret
    align 8
global::bs_get_utf8_shared:
    mov edx, 524238655
    pext edx, eax, edx
    push rdi
    push rsi
    mov esi, eax
    not esi
    lzcnt esi, esi
    mov ecx, 4
    sub ecx, esi
    lea ecx, qword ptr [rcx*8]
    shrx eax, eax, ecx
    mov r8d, 12632256
    shrx r8d, r8d, ecx
    mov r9d, 8421504
    shrx r9d, r9d, ecx
    mov ecx, 4
    sub ecx, esi
    add ecx, ecx
    lea ecx, qword ptr [rcx+rcx*2]
    and eax, r8d
    cmp eax, r9d
    cmovne esi, r9d
    shrx eax, edx, ecx
    and eax, -4194305
    cmp eax, 1114111
    cmova esi, r9d
    mov ecx, eax
    and ecx, -2048
    cmp ecx, 55296
    cmove esi, r9d
    lea ecx, qword ptr [rsi*4]
    cmp esi, 4
    setne dl
    sub cl, dl
    movzx rcx, cl
    shrx edx, eax, ecx
    test edx, edx
    cmove esi, r9d
    pop rdx
    pop rdi
    lea rdx, qword ptr [rdx+rsi*8]
    sub esi, 2
    cmp esi, 2
    ja L108
    mov qword ptr [rdi+16], rdx
    shl eax, 4
    or eax, 15
    ret
L108:
    xor rax, rax
    ret
    align 8
global::bs_get_utf8_short_shared:
    shr rax, 3
    test rax, rax
    short jne L109
    ret
L109:
    mov r8, rax
    test rsi, 7
    setne cl
    movzx ecx, cl
    add rax, rcx
    push rsi
    shr rsi, 3
    cmp rax, 2
    short je L110
    short ja L111
    mov al, byte ptr [rdx+rsi]
    movzx eax, al
    short jmp L114
L110:
    mov ax, word ptr [rdx+rsi]
    movzx eax, ax
    short jmp L114
L111:
    cmp rax, 4
    short je L112
    short ja L113
    mov al, byte ptr [rdx+rsi+2]
    movzx eax, al
    shl eax, 16
    mov ax, word ptr [rdx+rsi]
    short jmp L114
L112:
    mov eax, dword ptr [rdx+rsi]
    short jmp L114
L113:
    mov eax, dword ptr [rdx+rsi]
    mov cl, byte ptr [rdx+rsi+4]
    movzx ecx, cl
    shl rcx, 32
    or rax, rcx
L114:
    pop rsi
    bswap rax
    mov ecx, esi
    and cl, 7
    shl rax, cl
    mov cl, 64
    cmp r8, 3
    short ja L115
    shl r8d, 3
    rex sub cl, r8b
    mov r8, -1
    shl r8, cl
    and rax, r8
L115:
    bt rax, 63
    short jnc L116
    shr rax, 32
    jmp global::bs_get_utf8_shared
L116:
    add qword ptr [rdi+16], 8
    shr rax, 52
    or rax, 15
    ret
    align 8
global::bs_init_bits_shared:
    lea rdx, qword ptr [rbx-16]
    mov rsi, rbx
    mov rdi, r13
    push rbp
    mov rbp, rsp
    call 94068434772784
    leave
    mov edi, dword ptr [r13+624]
    test edi, 2048
    short jne L117
    ret
L117:
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    jmp global::do_schedule
    align 8
global::call_bif_shared:
    mov qword ptr [r13+464], rsi
    movzx r8d, byte ptr [rsi+16]
    rex mov byte ptr [r13+133], r8b
    mov qword ptr [r13+248], rdx
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    call 94068434771600
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    mov rdi, 94068445118180
    mov edi, dword ptr [rdi]
    cmp r12, 3
    cmovne r12, rdi
    test eax, eax
    short je L118
# Do return and dispatch to it
    mov qword ptr [rbx], rax
    ret
L118:
    cmp qword ptr [r13+104], 1024
    jne L120
# yield
# test trap to hibernate
    mov edi, dword ptr [r13+124]
    mov esi, edi
    and esi, 1
    short je L119
# do hibernate trap
    and edi, -2
    mov dword ptr [r13+124], edi
    jmp global::do_schedule
L119:
# do normal trap
    mov rdx, qword ptr [r13+248]
    jmp global::context_switch_simplified
L120:
    mov rsi, rsp
    mov qword ptr [r13+88], rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435482256
    mov rsp, qword ptr [r13+88]
    mov rsi, rax
    mov rcx, qword ptr [r13+464]
    jmp global::raise_exception_shared
    align 8
global::call_light_bif_shared:
    mov rdi, qword ptr [r13+544]
    mov qword ptr [rbx-56], rdx
    mov qword ptr [rbx-48], rcx
    mov qword ptr [rbx-40], rdi
    cmp dword ptr [rcx+36], 0
    jne L121
    cmp r12, 3
    je L121
    dec r14d
    jle L122
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    mov rcx, rax
    call rcx
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    mov rdi, 94068445118180
    mov edi, dword ptr [rdi]
    cmp r12, 3
    cmovne r12, rdi
    test dword ptr [r13+124], 3072
    jne L124
    mov rdi, qword ptr [r13+584]
    cmp qword ptr [r13+528], rdi
    ja L124
    mov rsi, qword ptr [r13+568]
    lea rdi, qword ptr [r15+rsi+3]
    cmp rsp, rdi
    jl L124
L123:
    test eax, eax
    short je L125
    mov qword ptr [rbx], rax
    ret
L125:
    cmp qword ptr [r13+104], 1024
    short jne L126
    mov rdx, qword ptr [r13+248]
    jmp global::context_switch_simplified
L126:
    mov rsi, qword ptr [rbx-56]
    mov rcx, qword ptr [rbx-48]
    add rcx, 64
    mov qword ptr [rsp], rsi
    jmp global::raise_exception_shared
L124:
    mov rsi, qword ptr [rbx-40]
    mov r8, qword ptr [rbx-48]
    movzx r8d, byte ptr [r8+80]
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rax
    mov rcx, rbx
    call 94068436940640
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    short jmp L123
L121:
    mov rax, rcx
    jmp qword ptr [rax+r12*8]
L122:
    movzx esi, byte ptr [rcx+80]
    lea rcx, qword ptr [rcx+64]
    rex mov byte ptr [r13+133], sil
    mov qword ptr [r13+464], rcx
    add rsp, 8
    jmp global::context_switch_simplified
    align 8
global::call_nif_early:
    mov rsi, qword ptr [rsp]
    sub rsi, 48
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068437239568
    mov rsp, rbp
    add rsp, 8
    mov rdx, rax
    jmp global::call_nif_shared
    align 8
global::call_nif_shared:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rdx
    mov rdx, rbx
    mov rcx, qword ptr [rsi+16]
    mov r8, qword ptr [rsi+24]
    mov r9, qword ptr [rsi+32]
    call 94068434771728
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    mov rdi, 94068445118180
    mov edi, dword ptr [rdi]
    cmp r12, 3
    cmovne r12, rdi
    test eax, eax
    short je L127
# Do return and dispatch to it
    mov qword ptr [rbx], rax
    ret
L127:
    cmp qword ptr [r13+104], 1024
    jne L129
# yield
# test trap to hibernate
    mov edi, dword ptr [r13+124]
    mov esi, edi
    and esi, 1
    short je L128
# do hibernate trap
    and edi, -2
    mov dword ptr [r13+124], edi
    jmp global::do_schedule
L128:
# do normal trap
    mov rdx, qword ptr [r13+248]
    jmp global::context_switch_simplified
L129:
    mov rsi, rsp
    mov qword ptr [r13+88], rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435482256
    mov rsp, qword ptr [r13+88]
    mov rsi, rax
    mov rcx, qword ptr [r13+464]
    jmp global::raise_exception_shared
    align 8
global::call_nif_yield_helper:
    dec r14d
    short jl L130
    jmp global::call_nif_shared
L130:
    movzx edi, byte ptr [rdx-8]
    rex mov byte ptr [r13+133], dil
    lea rdi, qword ptr [rdx-24]
    mov qword ptr [r13+464], rdi
    add rdx, 40
    jmp global::context_switch_simplified
    align 8
global::catch_end_shared:
    mov rsi, qword ptr [rbx+8]
    cmp qword ptr [rbx+24], 715
    short jne L131
    mov qword ptr [rbx], rsi
    ret
L131:
    cmp qword ptr [rbx+24], 779
    jne L132
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, qword ptr [rbx+16]
    call 94068435484320
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov rsi, rax
L132:
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L133
    mov qword ptr [rbx], rsi
    mov ecx, 1
.db 0x66, 0x90
    call global::garbage_collect
    mov rsi, qword ptr [rbx]
L133:
    mov qword ptr [r15], 128
    mov qword ptr [r15+8], 1483
    mov qword ptr [r15+16], rsi
    lea rax, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], rax
    ret
    align 8
global::check_float_error:
    vmovsd xmm1, qword ptr [L135]
    vandpd xmm2, xmm0, xmmword ptr [L136]
    vucomisd xmm1, xmm2
    short jb L134
    ret
L134:
    mov qword ptr [r13+104], 4176
    sub rcx, rcx
    jmp global::raise_exception
    align 16
L136:
.dq 0x7FFFFFFFFFFFFFFF
L135:
.dq 0x7FEFFFFFFFFFFFFF
    align 8
global::construct_utf8_shared:
    mov eax, edx
    and eax, 63
    cmp edx, 2048
    jae L137
    shl eax, 8
    shr rdx, 6
    or edx, eax
    or edx, 32960
    mov esi, 16
    ret
L137:
    cmp edx, 65536
    jae L138
    shl eax, 16
    lea edi, [rdx*4]
    and edi, 16128
    shr edx, 12
    or edx, edi
    or edx, eax
    or edx, 8421600
    mov esi, 24
    ret
L138:
    shl eax, 24
    mov edi, edx
    shl edi, 10
    and edi, 4128768
    mov esi, edx
    shr esi, 4
    and esi, 16128
    shr edx, 18
    or edx, eax
    or edx, edi
    or edx, esi
    or edx, -2139062032
    mov esi, 32
    ret
    align 8
global::dispatch_bif:
    mov rdx, qword ptr [r13+248]
    lea rsi, qword ptr [rdx-24]
    mov rcx, qword ptr [rdx+16]
    jmp global::call_bif_shared
    align 8
global::dispatch_nif:
    mov rdx, qword ptr [r13+248]
    jmp global::call_nif_shared
    align 8
global::dispatch_return:
    pop rdx
    mov qword ptr [r13+464], 0
    mov byte ptr [r13+133], 1
    jmp global::context_switch_simplified
    align 8
global::dispatch_save_calls_export:
    mov qword ptr [rbx-56], rax
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rax
    call 94068435975248
    mov rsp, rbp
    mov rax, qword ptr [rbx-56]
    mov rdi, 94068445118180
    mov edi, dword ptr [rdi]
    jmp qword ptr [rax+rdi*8]
    align 8
global::dispatch_save_calls_fun:
    mov rdi, 94068445118180
    mov edi, dword ptr [rdi]
    jmp qword ptr [rax+rdi*8]
    align 8
global::export_trampoline:
    mov rdi, qword ptr [rax+96]
    cmp rdi, 108
    je global::generic_bp_global
    cmp rdi, 30
    je L139
    cmp rdi, 32
    je L140
# Unexpected export trampoline op
    ud2
L139:
    lea rsi, qword ptr [rax+64]
    mov rdx, qword ptr [r13+248]
    mov rcx, qword ptr [rax+104]
    jmp global::call_bif_shared
L140:
    lea rsi, qword ptr [rax+64]
    mov qword ptr [rbx-56], rsi
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rbx
    mov ecx, 1035
    call 94068435488352
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    mov rcx, qword ptr [rbx-56]
    test rax, rax
    je global::raise_exception
    jmp qword ptr [rax+r12*8]
    align 8
global::garbage_collect:
    sub rdx, r15
    shr rdx, 3
    lea rsi, qword ptr [rdx-4]
    mov rax, qword ptr [rsp]
    mov qword ptr [r13+248], rax
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rbx
    mov r8d, r14d
    call 94068436941344
    sub r14d, eax
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov edi, dword ptr [r13+624]
    test edi, 2048
    short jne L141
    ret
L141:
    add rsp, 8
    jmp global::do_schedule
    align 8
global::generic_bp_global:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [rax+48]
    mov rdx, rbx
    call 94068435537856
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    jmp rax
    align 8
global::generic_bp_local:
    pop qword ptr [rbx-48]
    pop rsi
    mov qword ptr [rbx-56], rsi
    sub rsi, 48
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rbx
    call 94068435537856
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    cmp rax, 98
    je global::debug_bp
    push qword ptr [rbx-56]
    push qword ptr [rbx-48]
    ret
    align 8
global::get_sint64_shared:
    rex test dil, 1
    jne L143
    mov rsi, qword ptr [rdi-2]
    mov rdx, qword ptr [rdi+6]
    and rsi, 63
    cmp rsi, 8
    je L142
    cmp rsi, 12
    jne L143
    neg rdx
L142:
    mov rdi, rdx
    test rsi, rsi
    ret
L143:
    xor rsi, rsi
    ret
    align 8
global::debug_bp:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, qword ptr [rbx-56]
    sub rsi, 8
    mov rdi, r13
    lea rsi, qword ptr [rsi-24]
    mov rdx, rbx
    mov rcx, 7179
    call 94068435488352
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    je L144
    jmp qword ptr [rax+r12*8]
L144:
    mov rsi, qword ptr [rbx-56]
    jmp global::raise_exception
    align 8
global::fconv_shared:
    mov rdi, rsi
    rex test sil, 1
    short jne L145
    mov rsi, qword ptr [rsi-2]
    and rsi, 59
    cmp rsi, 8
    short jne L145
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    lea rsi, qword ptr [rbx-56]
    call 94068436847152
    mov rsp, rbp
    test eax, eax
    short js L145
    vmovsd xmm0, qword ptr [rbx-56]
    ret
L145:
    mov qword ptr [r13+104], 4176
    sub rcx, rcx
    jmp global::raise_exception
    align 8
global::handle_call_fun_error:
    test cl, 1
    jne L147
    cmp byte ptr [rcx-2], 20
    short je L146
L147:
    mov qword ptr [r13+104], 10320
    mov qword ptr [r13+112], rcx
    push r8
    xor ecx, ecx
    jmp global::raise_exception
L146:
    mov qword ptr [rbx-56], rcx
    mov qword ptr [rbx-48], r8
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    shr rdx, 8
    call 94068434777344
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov rdi, qword ptr [rbx-56]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rax
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L148
    mov ecx, 2
.db 0x66, 0x90
    call global::garbage_collect
L148:
    mov rdi, qword ptr [rbx]
    mov rsi, qword ptr [rbx+8]
    mov qword ptr [r15], 128
    mov qword ptr [r15+8], rdi
    mov qword ptr [r15+16], rsi
    lea rdi, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [r13+104], 11344
    mov qword ptr [r13+112], rdi
    push qword ptr [rbx-48]
    xor ecx, ecx
    jmp global::raise_exception
    align 8
global::handle_element_error:
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    mov qword ptr [r13+104], 3152
    mov rcx, 94068445024672
    jmp global::raise_exception
    align 8
global::handle_hd_error:
    mov qword ptr [rbx], rax
    mov qword ptr [r13+104], 3152
    mov rcx, 94068445024640
    jmp global::raise_exception
    align 8
global::handle_map_get_badkey:
    mov qword ptr [rbx], rsi
    mov qword ptr [rbx+8], rdi
    mov qword ptr [r13+104], 19536
    mov qword ptr [r13+112], rsi
    mov rcx, 94068445024576
    jmp global::raise_exception
    align 8
global::handle_map_get_badmap:
    mov qword ptr [rbx], rsi
    mov qword ptr [rbx+8], rdi
    mov qword ptr [r13+104], 18512
    mov qword ptr [r13+112], rdi
    mov rcx, 94068445024608
    jmp global::raise_exception
    align 8
global::handle_map_size_error:
    mov qword ptr [rbx], rax
    mov qword ptr [r13+112], rax
    mov qword ptr [r13+104], 18512
    mov rcx, 94068445024544
    jmp global::raise_exception
    align 8
global::handle_node_error:
    mov qword ptr [rbx], rdi
    mov qword ptr [r13+104], 3152
    mov rcx, 94068445024512
    jmp global::raise_exception
    align 8
global::i_band_body_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rax
    mov rdi, r13
    mov rdx, rax
    call 94068436387472
    mov rsp, rbp
    test eax, eax
    short je L149
    ret
L149:
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    mov rcx, 94068441273616
    jmp global::raise_exception
    align 8
global::i_band_guard_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rax
    call 94068436387472
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::i_bif_body_shared:
    mov rbp, rsp
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rcx
    mov rdi, r13
    xor edx, edx
    call rcx
    test eax, eax
    short je L150
    mov rsp, rbp
    mov r14d, dword ptr [r13+120]
    ret
L150:
    mov rsi, qword ptr [rbx-56]
    mov rdi, qword ptr [rsi]
    mov qword ptr [rbx], rdi
    mov rdi, qword ptr [rsi+8]
    mov qword ptr [rbx+8], rdi
    mov rdi, qword ptr [rsi+16]
    mov qword ptr [rbx+16], rdi
    mov rdi, qword ptr [rbx-48]
    call 94068435482128
    mov rsp, rbp
    mov r14d, dword ptr [r13+120]
    mov rcx, rax
    jmp global::raise_exception
    align 8
global::i_bif_guard_shared:
    mov rbp, rsp
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    xor edx, edx
    call rcx
    mov rsp, rbp
    mov r14d, dword ptr [r13+120]
    test eax, eax
    ret
    align 8
global::i_bor_body_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rax
    mov rdi, r13
    mov rdx, rax
    call 94068436388672
    mov rsp, rbp
    test eax, eax
    short je L151
    ret
L151:
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    mov rcx, 94068441273584
    jmp global::raise_exception
    align 8
global::i_bor_guard_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rax
    call 94068436388672
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::i_bnot_body_shared:
    xor rax, -16
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rax
    mov rdi, r13
    mov rsi, rax
    call 94068436391072
    mov rsp, rbp
    test eax, eax
    short je L152
    ret
L152:
    mov rdi, qword ptr [rbx-56]
    mov qword ptr [rbx], rdi
    mov rcx, 94068441273520
    jmp global::raise_exception
    align 8
global::i_bnot_guard_shared:
    xor rax, -16
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rax
    call 94068436391072
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::i_breakpoint_trampoline_shared:
    mov rax, qword ptr [rsp]
    movzx eax, byte ptr [rax-41]
    cmp eax, 3
    short je L153
    cmp eax, 1
    short je L155
    cmp eax, 2
    short je L154
    ret
L153:
.db 0x0F, 0x1F, 0x00
    call global::generic_bp_local
L155:
    jmp global::call_nif_early
L154:
.db 0x66, 0x90
    call global::generic_bp_local
    ret
    align 8
global::i_bsl_guard_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rax
    call 94068436367568
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::i_bsl_body_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rax
    mov rdi, r13
    mov rdx, rax
    call 94068436367568
    mov rsp, rbp
    test eax, eax
    short je L156
    ret
L156:
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    mov rcx, 94068441273456
    jmp global::raise_exception
    align 8
global::i_bsr_guard_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rax
    call 94068436368400
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::i_bsr_body_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rax
    mov rdi, r13
    mov rdx, rax
    call 94068436368400
    mov rsp, rbp
    test eax, eax
    short je L157
    ret
L157:
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    mov rcx, 94068441273488
    jmp global::raise_exception
    align 8
global::i_bxor_body_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rax
    mov rdi, r13
    mov rdx, rax
    call 94068436389872
    mov rsp, rbp
    test eax, eax
    short je L158
    ret
L158:
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    mov rcx, 94068441273552
    jmp global::raise_exception
    align 8
global::i_bxor_guard_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rax
    call 94068436389872
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::i_func_info_shared:
    pop rdi
    and rdi, -8
    add rdi, 16
    mov qword ptr [r13+104], 6224
    mov qword ptr [r13+464], rdi
    xor esi, esi
    xor ecx, ecx
    jmp global::raise_exception_shared
    align 8
global::i_get_map_element_shared:
    mov eax, esi
    and al, 3
    cmp al, 3
    short jne L159
    mov eax, dword ptr [rdi-2]
    mov ecx, eax
    and ecx, 252
    cmp ecx, 44
    short jne L160
    mov eax, dword ptr [rdi+6]
    mov rcx, qword ptr [rdi+14]
L162:
    dec eax
    short jl L161
    cmp rsi, qword ptr [rcx+rax*8+6]
    short jne L162
    mov rax, qword ptr [rdi+rax*8+22]
L161:
    ret
L159:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068435491984
    mov rsp, rbp
    test eax, eax
    rex setnz dil
    rex dec dil
    ret
L160:
    mov rcx, rsi
    shr rcx, 33
    mov rdx, rsi
    xor rdx, rcx
    mov r9, -49064778989728563
    mulx rcx, rdx, r9
    mov rcx, rdx
    shr rcx, 33
    xor rdx, rcx
    mov r9, -4265267296055464877
    mulx rcx, rdx, r9
    mov rcx, rdx
    shr rcx, 33
    xor rdx, rcx
    add rdi, 8
    xor r8d, r8d
L163:
    mov ecx, edx
    and ecx, 15
    shr rdx, 4
    inc r8d
    sar eax, 16
    cmp eax, -1
    short je L166
    bt eax, ecx
    short jnc L164
    bzhi eax, eax, ecx
    popcnt ecx, eax
L166:
    mov rdi, qword ptr [rdi+rcx*8+6]
    rex test dil, 2
    short je L165
    mov eax, dword ptr [rdi-2]
    test r8d, 15
    short jnz L163
    short jmp L167
L165:
    cmp qword ptr [rdi-1], rsi
    mov rax, qword ptr [rdi+7]
L164:
    ret
L167:
    shr eax, 6
    lea r9d, qword ptr [eax-1]
L168:
    mov rdx, qword ptr [rdi+r9*8+6]
    cmp rsi, qword ptr [rdx-1]
    mov rax, qword ptr [rdx+7]
    short jz L164
    dec r9d
    short jns L168
    ret
    align 8
global::i_get_map_element_hash_shared:
    mov eax, dword ptr [rdi-2]
    mov ecx, eax
    and ecx, 252
    cmp ecx, 44
    short jne L169
    mov eax, dword ptr [rdi+6]
    mov rcx, qword ptr [rdi+14]
L171:
    dec eax
    short jl L170
    cmp rsi, qword ptr [rcx+rax*8+6]
    short jne L171
    mov rax, qword ptr [rdi+rax*8+22]
L170:
    ret
L169:
    add rdi, 8
    xor r8d, r8d
L172:
    mov ecx, edx
    and ecx, 15
    shr rdx, 4
    inc r8d
    sar eax, 16
    cmp eax, -1
    short je L175
    bt eax, ecx
    short jnc L173
    bzhi eax, eax, ecx
    popcnt ecx, eax
L175:
    mov rdi, qword ptr [rdi+rcx*8+6]
    rex test dil, 2
    short je L174
    mov eax, dword ptr [rdi-2]
    test r8d, 15
    short jnz L172
    short jmp L176
L174:
    cmp qword ptr [rdi-1], rsi
    mov rax, qword ptr [rdi+7]
L173:
    ret
L176:
    shr eax, 6
    lea r9d, qword ptr [eax-1]
L177:
    mov rdx, qword ptr [rdi+r9*8+6]
    cmp rsi, qword ptr [rdx-1]
    mov rax, qword ptr [rdx+7]
    short jz L173
    dec r9d
    short jns L177
    ret
    align 8
global::i_load_nif_shared:
    mov qword ptr [rbx-56], rsi
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rdx, rbx
    call 94068434772048
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    cmp rax, 2
    short je L178
    cmp rax, 0
    short jne L179
    ret
L179:
    mov rcx, 94068445024448
    jmp global::raise_exception
L178:
    mov rdx, qword ptr [rbx-56]
    jmp global::context_switch_simplified
    align 8
global::i_length_guard_shared:
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rdx
    mov rbp, rsp
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [rbx+rsi*8]
    call 94068435803568
    mov rsp, rbp
    mov r14d, dword ptr [r13+120]
    test eax, eax
    short je L181
    ret
L181:
    mov rsi, qword ptr [rbx-56]
    mov rdx, qword ptr [rbx-48]
    cmp qword ptr [r13+104], 1024
    jne L180
    add rsi, 2
    add rsp, 8
    mov qword ptr [r13+464], 0
    rex mov byte ptr [r13+133], sil
    jmp global::context_switch_simplified
L180:
    sub rax, rax
    ret
    align 8
global::i_length_body_shared:
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rdx
    mov rbp, rsp
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea rsi, qword ptr [rbx+rsi*8]
    call 94068435803568
    mov rsp, rbp
    mov r14d, dword ptr [r13+120]
    test eax, eax
    short je L183
    ret
L183:
    mov rsi, qword ptr [rbx-56]
    mov rdx, qword ptr [rbx-48]
    cmp qword ptr [r13+104], 1024
    jne L182
    add rsi, 3
    add rsp, 8
    mov qword ptr [r13+464], 0
    rex mov byte ptr [r13+133], sil
    jmp global::context_switch_simplified
L182:
    mov rdi, qword ptr [rbx+rsi*8+16]
    mov qword ptr [rbx], rdi
    mov rcx, 94068441274400
    jmp global::raise_exception
    align 8
global::i_line_breakpoint_trampoline_shared:
    mov qword ptr [rbx-56], r10
    mov r11, qword ptr [rsp]
    sub r11, 8
    mov qword ptr [rbx-48], r11
    mov rcx, r10
    lea rax, [abs r10*8]
    mov qword ptr [rbx-40], rax
    lea rdx, [rax+32]
    lea rdx, qword ptr [r15+rdx]
    cmp rdx, rsp
    short jbe L186
.db 0x0F, 0x1F, 0x00
    call global::garbage_collect
    mov rax, qword ptr [rbx-40]
L186:
    sub rsp, rax
    mov rdi, r13
    mov rsi, qword ptr [rbx-48]
    mov rdx, qword ptr [rbx-56]
    mov rcx, rbx
    lea r8, qword ptr [rsp]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068435542912
    mov rsp, rbp
    test rax, rax
    jnz L187
    mov rax, qword ptr [rbx-40]
    jmp L185
L187:
    call qword ptr [rax+r12*8]
.db 0x66, 0x90
    call qword ptr [rax+r12*8]
global::i_line_breakpoint_cleanup:
    mov rdi, rbx
    lea rsi, qword ptr [rsp]
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    call 94068435543216
    mov rsp, rbp
    lea rax, [abs rax*8]
L185:
    add rsp, rax
L184:
    ret
    align 8
global::i_loop_rec_shared:
    or dword ptr [r13+124], 8192
    mov qword ptr [r13+248], rdi
    mov qword ptr [rbx-56], rsi
L188:
    test r14d, r14d
    jle L190
# Peek next message
L189:
    mov rdi, qword ptr [r13+328]
    mov rdi, qword ptr [rdi]
    test rdi, rdi
    jne L191
# Inner queue empty, fetch more from outer/middle queues
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-48], 0
    mov rdi, r13
    mov esi, r14d
    xor edx, edx
    lea rcx, qword ptr [rbx-48]
    lea r8, dword ptr [rbx-40]
    call 94068436334608
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov rdi, 94068445118180
    mov edi, dword ptr [rdi]
    cmp r12, 3
    cmovne r12, rdi
    sub r14d, eax
    mov rdi, qword ptr [rbx-48]
    test rdi, rdi
    jne L191
    cmp dword ptr [rbx-40], 0
    short jne L190
    and dword ptr [r13+124], -8193
    add rsp, 8
    jmp qword ptr [rbx-56]
L190:
    and dword ptr [r13+124], -8193
    mov byte ptr [r13+133], 0
    mov qword ptr [r13+464], 0
    add rsp, 8
    jmp global::do_schedule
# Check if message is distributed
L191:
    cmp qword ptr [rdi+16], 0
    jne L192
    sub r14d, 10
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rdi
    mov rdi, r13
    call 94068434774672
    mov rsp, rbp
    test rax, rax
    je L188
    mov rdi, rax
L192:
    mov rdi, qword ptr [rdi+16]
    mov qword ptr [rbx], rdi
    ret
    align 8
global::i_test_yield_shared:
    lea rsi, qword ptr [rdx-48]
    mov qword ptr [r13+464], rsi
    movzx esi, byte ptr [rsi+16]
    rex mov byte ptr [r13+133], sil
    jmp global::context_switch_simplified
    align 8
global::int_div_rem_body_shared:
    cmp rcx, 15
    je L193
    mov esi, edi
    and esi, ecx
    and esi, 15
    cmp esi, 15
    jne L194
    mov r9, rcx
    sar r9, 4
    mov rax, rdi
    sar rax, 4
    cqo
    idiv r9
    mov r9, rax
    sal rax, 4
    sal rdx, 4
    or rax, 15
    or rdx, 15
    sar r9, 59
    cmp r9, 1
    short jge L194
    ret
L194:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rdi
    mov qword ptr [rbx-48], rcx
    mov qword ptr [rbx-40], r8
    mov rsi, rdi
    mov rdx, rcx
    lea rcx, qword ptr [rbx-32]
    lea r8, qword ptr [rbx-24]
    mov rdi, r13
    call 94068436377616
    mov rsp, rbp
    test eax, eax
    mov rax, qword ptr [rbx-32]
    mov rdx, qword ptr [rbx-24]
    short je L195
    ret
L193:
    mov qword ptr [r13+104], 4176
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rcx
    mov rcx, r8
    jmp global::raise_exception
L195:
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    mov rcx, qword ptr [rbx-40]
    jmp global::raise_exception
    align 8
global::int_div_rem_guard_shared:
    cmp rcx, 15
    je L196
    mov esi, edi
    and esi, ecx
    and esi, 15
    cmp esi, 15
    jne L197
    mov r8, rcx
    sar r8, 4
    mov rax, rdi
    sar rax, 4
    cqo
    idiv r8
    mov r8, rax
    sal rax, 4
    sal rdx, 4
    or rax, 15
    or rdx, 15
    sar r8, 59
    cmp r8, 1
    jl L196
L197:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rsi, rdi
    mov rdx, rcx
    lea rcx, qword ptr [rbx-56]
    lea r8, qword ptr [rbx-48]
    mov rdi, r13
    call 94068436377616
    mov rsp, rbp
    test eax, eax
    mov rax, qword ptr [rbx-56]
    mov rdx, qword ptr [rbx-48]
L196:
    ret
    align 8
global::is_eq_exact_list_shared:
    short jmp L199
L198:
    mov rax, qword ptr [rdi-1]
    mov rdi, qword ptr [rdi+7]
    cmp qword ptr [rsi-1], rax
    short jne L200
    mov rsi, qword ptr [rsi+7]
L199:
    cmp rdi, rsi
    short je L200
    mov eax, edi
    or eax, esi
    test al, 2
    short je L198
    cmp al, 0
L200:
    ret
    align 8
global::is_eq_exact_shallow_boxed_shared:
    mov eax, edi
    or eax, esi
    test al, 1
    jne L203
    and rdi, -8
    and rsi, -8
    mov rdx, qword ptr [rdi]
    shr rdx, 6
    dec rdx
    xor ecx, ecx
L201:
    vmovdqu xmm0, xmmword ptr [rdi+rcx]
    vpxor xmm0, xmm0, xmmword ptr [rsi+rcx]
    vptest xmm0, xmm0
    short jne L202
    add rcx, 16
    sub rdx, 2
    short jge L201
    cmp dl, -2
    short je L202
    mov rax, qword ptr [rdi+rcx]
    cmp rax, qword ptr [rsi+rcx]
L202:
    ret
L203:
    cmp al, 0
    ret
    align 8
global::is_in_range_shared:
    rex test dil, 1
    jne L204
    cmp qword ptr [rdi-2], 88
    short jne L205
    vmovsd xmm0, qword ptr [rdi+6]
    sar rsi, 4
    sar rdx, 4
    vcvtsi2sd xmm1, xmm1, rsi
    vcvtsi2sd xmm2, xmm2, rdx
    mov rax, -1
    xor ecx, ecx
    vucomisd xmm0, xmm2
    seta cl
    vucomisd xmm1, xmm0
    cmovbe rax, rcx
    cmp rax, 0
    ret
L204:
    mov eax, 1
    cmp rax, 0
    ret
L205:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rdi
    mov qword ptr [rbx-48], rdx
# erts_cmp_compound(X, Y, 0, 0);
    xor edx, edx
    xor ecx, ecx
    call 94068436048800
    test rax, rax
    js L206
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
# erts_cmp_compound(X, Y, 0, 0);
    xor edx, edx
    xor ecx, ecx
    call 94068436048800
    test rax, rax
L206:
    mov rsp, rbp
    ret
    align 8
global::is_ge_lt_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rdi
    mov qword ptr [rbx-48], rdx
# erts_cmp_compound(Src, A, 0, 0);
    xor edx, edx
    xor ecx, ecx
    call 94068436048800
    test rax, rax
    short js L207
# erts_cmp_compound(B, Src, 0, 0);
    mov rdi, qword ptr [rbx-48]
    mov rsi, qword ptr [rbx-56]
    xor edx, edx
    xor ecx, ecx
    call 94068436048800
    mov rdi, -1
    mov ecx, 1
    test rax, rax
    cmovs rax, rdi
    cmovg rax, rcx
    add rax, 1
L207:
    mov rsp, rbp
    ret
    align 8
global::minus_body_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rdx
    mov rdi, r13
    call 94068436373296
    mov rsp, rbp
    test eax, eax
    short je L208
    ret
L208:
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    mov rcx, 94068441273904
    jmp global::raise_exception
    align 8
global::minus_guard_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436373296
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::mul_add_body_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rdx
    mov rdi, r13
    cmp rcx, 15
    short je L209
    mov qword ptr [rbx-32], rcx
    lea r8, qword ptr [rbx-40]
    call 94068436375920
    mov rsp, rbp
    test eax, eax
    short je L210
    ret
L209:
    call 94068436374496
    mov rsp, rbp
    test eax, eax
    short je L211
    ret
L210:
    mov rdi, qword ptr [rbx-40]
    mov rsi, qword ptr [rbx-32]
    mov rcx, 94068441273648
    test edi, edi
    short jne L212
L211:
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
    mov rcx, 94068441273680
L212:
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    jmp global::raise_exception
    align 8
global::mul_add_guard_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rcx
    mov rdi, r13
    call 94068436374496
    test eax, eax
    short je L213
    mov rdx, qword ptr [rbx-56]
    mov rsi, rax
    mov rdi, r13
    cmp rdx, 15
    short je L213
    call 94068436371424
L213:
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::mul_body_shared:
    mov ecx, 15
    jmp global::mul_add_body_shared
    align 8
global::mul_guard_shared:
    mov ecx, 15
    short jmp global::mul_add_guard_shared
    align 8
global::new_map_shared:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    call 94068435492560
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    ret
    align 8
global::plus_body_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov qword ptr [rbx-48], rdx
    mov rdi, r13
    call 94068436371424
    mov rsp, rbp
    test eax, eax
    short je L214
    ret
L214:
    mov rdi, qword ptr [rbx-56]
    mov rsi, qword ptr [rbx-48]
    mov qword ptr [rbx], rdi
    mov qword ptr [rbx+8], rsi
    mov rcx, 94068441273936
    jmp global::raise_exception
    align 8
global::plus_guard_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436371424
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::process_exit:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    xor esi, esi
    xor ecx, ecx
    mov rdx, rbx
    call 94068435484480
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test rax, rax
    je global::do_schedule
# End of process
    ud2
    align 8
global::process_main:
    sub rsp, 16592
    and rsp, -64
    mov qword ptr [rdi], rsp
    lea rbx, qword ptr [rsp+64]
    mov qword ptr [rbx+16448], 0
    mov qword ptr [rbx+16456], 0
    xor r13d, r13d
    xor r14d, r14d
    xor edx, edx
    jmp L218
L217:
    mov rdx, qword ptr [r13+184]
    sub edx, r14d
    jmp L218
L215:
# Context switch, unknown arity/MFA
    movzx edi, byte ptr [rdx-8]
    rex mov byte ptr [r13+133], dil
    lea rdi, qword ptr [rdx-24]
    mov qword ptr [r13+464], rdi
L216:
# Context switch, known arity and MFA
    sub rbp, rbp
    mov qword ptr [r13+248], rdx
    mov edi, dword ptr [r13+624]
    test edi, 2048
    short je L219
# Process exiting
    lea rdi, qword ptr [global::process_exit]
    mov qword ptr [r13+248], rdi
    mov byte ptr [r13+133], 0
    mov qword ptr [r13+464], 0
    short jmp L217
L219:
    mov rdx, qword ptr [r13+184]
    sub edx, r14d
    mov r14d, edx
    mov rdi, r13
    mov rsi, rbx
    call 94068435481648
    mov edx, r14d
L218:
# schedule_next
    cmp qword ptr [rbx+16456], 0
    short je L220
    mov rdi, r13
    mov rsi, qword ptr [rbx+16456]
    mov qword ptr [rbx+16456], rdx
    mov rdx, qword ptr [rbx+16448]
    call 94068435482016
    mov rdx, qword ptr [rbx+16456]
L220:
    xor edi, edi
    mov rsi, r13
    call 94068434669328
    mov r13, rax
    mov rdi, 94068445113312
    cmp qword ptr [rdi], 0
    mov qword ptr [rbx+16456], 0
    short je L221
    call 94068436067760
    mov qword ptr [rbx+16456], rax
    mov rax, qword ptr [r13+248]
    mov qword ptr [rbx+16448], rax
L221:
    mov rdi, r13
    mov rsi, rbx
    call 94068435481920
    mov r14d, dword ptr [r13+120]
    mov qword ptr [r13+184], r14
    mov rdi, r13
    mov rsi, 1
    call 94068434809184
    test rax, rax
    mov rdi, 94068445118180
    mov rsi, 3
    mov r12d, dword ptr [rdi]
    cmovnz r12, rsi
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov rax, qword ptr [r13+248]
    cmp qword ptr [rax], 34
    je global::dispatch_nif
    cmp qword ptr [rax], 30
    je global::dispatch_bif
    jmp rax
global::context_switch:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    jmp L215
global::context_switch_simplified:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    jmp L216
global::do_schedule:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    jmp L217
    align 8
global::raise_exception:
    pop rsi
    and rsi, -4
    push rsi
    jmp global::raise_exception_shared
    align 8
global::raise_exception_null_exp:
    xor ecx, ecx
    short jmp global::raise_exception
    align 8
global::raise_exception_shared:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    test esi, 3
    short jne L222
    mov rdi, r13
    mov rdx, rbx
    call 94068435484480
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    test rax, rax
    short je global::do_schedule
    jmp rax
L222:
# Error address is not a CP or NULL or ARG2 and ARG4 are unset
    ud2
    align 8
global::raise_shared:
    mov qword ptr [r13+112], rdx
    mov qword ptr [r13+288], rsi
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068435483136
    mov rsp, rbp
    xor ecx, ecx
    short jmp global::raise_exception
    align 8
global::store_unaligned:
    movzx eax, byte ptr [rdi]
    xchg rdx, rcx
    mov rsi, r8
    and rsi, 255
    shr rsi, cl
    shl eax, cl
    and eax, -256
    shr eax, cl
    xchg rdx, rcx
    or eax, esi
    mov byte ptr [rdi], al
    add rdi, 1
    mov esi, 8
    sub rsi, rdx
    xchg rsi, rcx
    bswap r8
    shl r8, cl
    xchg rsi, rcx
    sub rcx, rsi
    jle L224
L223:
    rol r8, 8
    rex mov byte ptr [rdi], r8b
    add rdi, 1
    sub rcx, 8
    short jg L223
L224:
    ret
    align 8
global::unary_minus_body_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov qword ptr [rbx-56], rsi
    mov rdi, r13
    call 94068436372640
    mov rsp, rbp
    test eax, eax
    short je L225
    ret
L225:
    mov rdi, qword ptr [rbx-56]
    mov qword ptr [rbx], rdi
    mov rcx, 94068441273872
    jmp global::raise_exception
    align 8
global::unary_minus_guard_shared:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068436372640
    mov rsp, rbp
    test eax, eax
    ret
    align 8
global::unloaded_fun:
    mov qword ptr [rbx-56], r8
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    shr rdx, 8
    call 94068434777584
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    mov rdi, 94068445118180
    mov edi, dword ptr [rdi]
    cmp r12, 3
    cmovne r12, rdi
    test rax, rax
    jz L226
    jmp qword ptr [rax+r12*8]
L226:
    push qword ptr [rbx-56]
    xor ecx, ecx
    jmp global::raise_exception
    align 8
global::update_map_assoc_shared:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    call 94068435493536
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    ret
    align 8
global::update_map_exact_guard_shared:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    call 94068435495840
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test eax, eax
    ret
    align 8
global::update_map_exact_body_shared:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    mov dword ptr [r13+120], r14d
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    mov rsi, rbx
    call 94068435495840
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    mov r14d, dword ptr [r13+120]
    test eax, eax
    short je L227
    ret
L227:
    xor ecx, ecx
    jmp global::raise_exception
    align 8
global::update_map_single_assoc_shared:
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    call 94068437343296
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    ret
    align 8
global::update_map_single_exact_body_shared:
    mov qword ptr [rbx-48], rsi
    vmovq xmm1, r15
    vpinsrq xmm0, xmm1, rsp, 1
    vmovdqu xmmword ptr [r13+80], xmm0
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, r13
    lea r8, qword ptr [rbx-56]
    call 94068437342272
    mov rsp, qword ptr [r13+88]
    mov r15, qword ptr [r13+80]
    test eax, eax
    short je L228
    mov rax, qword ptr [rbx-56]
    ret
L228:
    mov rax, qword ptr [rbx-48]
    mov qword ptr [r13+104], 19536
    mov qword ptr [r13+112], rax
    xor ecx, ecx
    jmp global::raise_exception
