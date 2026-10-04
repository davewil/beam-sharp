    align 8
L141:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# i_func_label_L
    align 8
label_1:
# func_line_I
# i_func_info_IaaI
# logger_config:new/1
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x72, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
new/1:
# i_breakpoint_trampoline
    short jmp L143
.db 0x90
    call L144
L143:
# i_test_yield
    lea rdx, qword ptr [new/1+24]
    dec r14d
    long jle L145
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L146
    mov ecx, 1
    call 139636653423200
L146:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
L147:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx+8], rdi
# line_I
# call_light_bif_be
    align 4
L148:
L149:
    long mov rcx, 9223372036854775807
    mov rax, 94068436610016
    lea rdx, qword ptr [L148]
# BIF: ets:new/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L150:
L151:
    long mov rcx, 9223372036854775807
    mov rax, 94068436613440
    lea rdx, qword ptr [L150]
# BIF: ets:whereis/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_3:
# func_line_I
# i_func_info_IaaI
# logger_config:delete/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0xE6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
delete/2:
# i_breakpoint_trampoline
    short jmp L153
.db 0x90
    call L144
L153:
# i_test_yield
    lea rdx, qword ptr [delete/2+24]
    dec r14d
    long jle L145
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L154
    mov ecx, 2
    call 139636653423200
L154:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
.db 0x90
    call table_key/1
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L155
    mov ecx, 1
    call 139636653423200
L155:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 204683
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 907
# call_light_bif_be
    align 4
L156:
L157:
    long mov rcx, 9223372036854775807
    mov rax, 94068435899424
    lea rdx, qword ptr [L156]
# BIF: persistent_term:put/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx], r10
# i_trim_t
    add rsp, 8
# line_I
# i_call_f
    call table_key/1
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# call_light_bif_be
    align 4
L158:
L159:
    long mov rcx, 9223372036854775807
    mov rax, 94068436620704
    lea rdx, qword ptr [L158]
# BIF: ets:delete/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_5:
# func_line_I
# i_func_info_IaaI
# logger_config:allow/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
allow/2:
# i_breakpoint_trampoline
    short jmp L160
.db 0x90
    call L144
L160:
# i_test_yield
    lea rdx, qword ptr [allow/2+24]
    dec r14d
    long jle L145
    align 4
# allocate_heap_tIt
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L161
    mov ecx, 2
    call 139636653423200
L161:
    sub rsp, 24
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp+8], xmm0
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 204683
    mov rdi, qword ptr [rbx+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 907
# line_I
# call_light_bif_be
    align 4
L162:
L163:
    long mov rcx, 9223372036854775807
    mov rax, 94068435902592
    lea rdx, qword ptr [L162]
# BIF: persistent_term:get/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# is_eq_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r10, 907
    jne label_7
# i_move_sd
    mov qword ptr [rbx+8], 95
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
L164:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# call_light_bif_be
    align 4
L165:
L166:
    long mov rcx, 9223372036854775807
    mov rax, 94068435902592
    lea rdx, qword ptr [L165]
# BIF: persistent_term:get/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L167
    mov ecx, 1
    call 139636653423200
L167:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 204683
    mov rdi, qword ptr [rsp+8]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+8], r11
# swap_dd
# (swapping using AVX)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rbx], xmm0
# line_I
# call_light_bif_be
    align 4
L168:
L169:
    long mov rcx, 9223372036854775807
    mov rax, 94068435899424
    lea rdx, qword ptr [L168]
# BIF: persistent_term:put/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx+8], r10
# jump_f
    jmp label_9
# label_L
label_7:
# is_ge_fss
    mov rsi, qword ptr [rbx]
    mov edi, 175
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L170
L171:
    cmp rdi, rsi
    short jmp L172
L170:
    call L174
L172:
    jl label_8
L173:
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# jump_f
    jmp label_9
# label_L
label_8:
# line_I
# i_minus_ssjd
    mov rsi, qword ptr [rbx]
    mov edx, 271
# is the operand small?
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L176
# skipped overflow test because the result is always small
    mov rax, rsi
    sub rax, 256
    short jmp L175
L176:
    call L177
L175:
    mov qword ptr [rbx+8], rax
# label_L
label_9:
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 24
    jmp less_or_equal_level/2
# i_func_label_L
    align 8
label_10:
# func_line_I
# i_func_info_IaaI
# logger_config:allow/1
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
allow/1:
# i_breakpoint_trampoline
    short jmp L178
.db 0x90
    call L144
L178:
# i_test_yield
    lea rdx, qword ptr [allow/1+24]
    dec r14d
    long jle L145
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L179
    mov ecx, 1
    call 139636653423200
L179:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov qword ptr [rbx+8], 95
# i_move_sd
L180:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# call_light_bif_be
    align 4
L181:
L182:
    long mov rcx, 9223372036854775807
    mov rax, 94068435902592
    lea rdx, qword ptr [L181]
# BIF: persistent_term:get/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# i_call_last_ft
    add rsp, 8
    jmp less_or_equal_level/2
# i_func_label_L
    align 8
label_12:
# func_line_I
# i_func_info_IaaI
# logger_config:less_or_equal_level/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x51, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
less_or_equal_level/2:
# i_breakpoint_trampoline
    short jmp L183
.db 0x90
    call L144
L183:
# i_test_yield
    lea rdx, qword ptr [less_or_equal_level/2+24]
    dec r14d
    long jle L145
    align 4
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 779
    je label_17
    cmp rsi, 22027
    je label_16
    cmp rsi, 47563
    je label_14
    cmp rsi, 81611
    je label_19
    cmp rsi, 214667
    je label_15
    cmp rsi, 400203
    je label_18
    cmp rsi, 400267
    je label_21
    cmp rsi, 400331
    je label_20
    jmp label_12
# label_L
label_14:
# bif_is_ge_ssd
    mov esi, 79
    mov rdi, qword ptr [rbx+8]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L184
    cmp rdi, rsi
    short jmp L185
L184:
    cmp rdi, rsi
    short je L185
    call L174
L185:
    mov eax, 75
    mov edi, 11
    cmovl rax, rdi
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L152
    ret
# label_L
label_15:
# bif_is_ge_ssd
    mov esi, 95
    mov rdi, qword ptr [rbx+8]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L186
    cmp rdi, rsi
    short jmp L187
L186:
    cmp rdi, rsi
    short je L187
    call L174
L187:
    mov eax, 75
    mov edi, 11
    cmovl rax, rdi
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L152
    ret
# label_L
label_16:
# bif_is_ge_ssd
    mov esi, 111
    mov rdi, qword ptr [rbx+8]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L188
    cmp rdi, rsi
    short jmp L189
L188:
    cmp rdi, rsi
    short je L189
    call L174
L189:
    mov eax, 75
    mov edi, 11
    cmovl rax, rdi
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L152
    ret
# label_L
label_17:
# bif_is_ge_ssd
    mov esi, 63
    mov rdi, qword ptr [rbx+8]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L190
    cmp rdi, rsi
    short jmp L191
L190:
    cmp rdi, rsi
    short je L191
    call L174
L191:
    mov eax, 75
    mov edi, 11
    cmovl rax, rdi
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L152
    ret
# label_L
label_18:
# bif_is_ge_ssd
    mov esi, 15
    mov rdi, qword ptr [rbx+8]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L192
    cmp rdi, rsi
    short jmp L193
L192:
    cmp rdi, rsi
    short je L193
    call L174
L193:
    mov eax, 75
    mov edi, 11
    cmovl rax, rdi
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L152
    ret
# label_L
label_19:
# bif_is_ge_ssd
    mov esi, 127
    mov rdi, qword ptr [rbx+8]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L194
    cmp rdi, rsi
    short jmp L195
L194:
    cmp rdi, rsi
    short je L195
    call L174
L195:
    mov eax, 75
    mov edi, 11
    cmovl rax, rdi
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L152
    ret
# label_L
label_20:
# bif_is_ge_ssd
    mov esi, 47
    mov rdi, qword ptr [rbx+8]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L196
    cmp rdi, rsi
    short jmp L197
L196:
    cmp rdi, rsi
    short je L197
    call L174
L197:
    mov eax, 75
    mov edi, 11
    cmovl rax, rdi
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L152
    ret
# label_L
label_21:
# bif_is_ge_ssd
    mov esi, 31
    mov rdi, qword ptr [rbx+8]
    mov eax, edi
    and al, 15
    cmp al, 15
    short jne L198
    cmp rdi, rsi
    short jmp L199
L198:
    cmp rdi, rsi
    short je L199
    call L174
L199:
    mov eax, 75
    mov edi, 11
    cmovl rax, rdi
    mov qword ptr [rbx], rax
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_22:
# func_line_I
# i_func_info_IaaI
# logger_config:exist/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x43, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
exist/2:
# i_breakpoint_trampoline
    short jmp L200
.db 0x90
    call L144
L200:
# i_test_yield
    lea rdx, qword ptr [exist/2+24]
    dec r14d
    long jle L145
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L201
    mov ecx, 2
    call 139636653423200
L201:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rbx], r11
# line_I
# i_call_f
.db 0x90
    call table_key/1
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# call_light_bif_be
    align 4
L202:
L203:
    long mov rcx, 9223372036854775807
    mov rax, 94068436614704
    lea rdx, qword ptr [L202]
# BIF: ets:member/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 8
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_24:
# func_line_I
# i_func_info_IaaI
# logger_config:get/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xC1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get/2:
# i_breakpoint_trampoline
    short jmp L204
.db 0x90
    call L144
L204:
# i_test_yield
    lea rdx, qword ptr [get/2+24]
    dec r14d
    long jle L145
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L205
    mov ecx, 2
    call 139636653423200
L205:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
.db 0x90
    call table_key/1
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# init_yregs_I
    mov qword ptr [rsp+8], 59
# call_light_bif_be
    align 4
L206:
L207:
    long mov rcx, 9223372036854775807
    mov rax, 94068436613856
    lea rdx, qword ptr [L206]
# BIF: ets:lookup/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_26
# (moving head and tail together)
    vmovups xmm0, xmmword ptr [rax-1]
    vmovups xmmword ptr [rbx+8], xmm0
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    jne label_27
    cmp dword ptr [rsi-2], 128
    jne label_27
# is_nil_fS
    cmp byte ptr [rbx+16], 59
    jne label_27
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L208
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L208:
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
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
    add rsp, 16
# return
    dec r14d
    jl L152
    ret
# label_L
label_26:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_27
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L209
    xor ecx, ecx
    call 139636653423200
L209:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 88651
    mov rdi, qword ptr [rsp]
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
    jl L152
    ret
# label_L
label_27:
# case_end_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 7248
    call L210
# i_func_label_L
    nop
    align 8
label_28:
# func_line_I
# i_func_info_IaaI
# logger_config:get/3
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0xC1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get/3:
# i_breakpoint_trampoline
    short jmp L211
.db 0x90
    call L144
L211:
# i_test_yield
    lea rdx, qword ptr [get/3+24]
    dec r14d
    long jle L145
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L212
    mov ecx, 3
    call 139636653423200
L212:
    sub rsp, 24
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+16], r10
# i_move_sd
    mov r11, qword ptr [rbx+8]
    mov qword ptr [rbx], r11
# line_I
# i_call_f
    call table_key/1
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L213
    mov ecx, 1
    call 139636653423200
L213:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 204683
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# i_move_sd
    mov qword ptr [rbx+8], 907
# line_I
# call_light_bif_be
    align 4
L214:
L215:
    long mov rcx, 9223372036854775807
    mov rax, 94068435902592
    lea rdx, qword ptr [L214]
# BIF: persistent_term:get/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 907
    jne label_30
# test_heap_It
    lea rdx, qword ptr [r15+80]
    cmp rdx, rsp
    short jbe L216
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L216:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 88651
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
    add rsp, 24
# return
    dec r14d
    jl L152
    ret
# label_L
label_30:
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx], r11
# init_yregs_I
    mov qword ptr [rsp], 59
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call less_or_equal_level/2
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 75
    jne label_31
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp+8], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 24
    jmp get/2
# label_L
label_31:
# i_move_sd
    mov qword ptr [rbx], 779
# deallocate_t
    add rsp, 24
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_32:
# func_line_I
# i_func_info_IaaI
# logger_config:create/3
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x43, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
create/3:
# i_breakpoint_trampoline
    short jmp L217
.db 0x90
    call L144
L217:
# i_test_yield
    lea rdx, qword ptr [create/3+24]
    dec r14d
    long jle L145
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 401163
    jne label_34
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L218
    mov ecx, 3
.db 0x66, 0x90
    call 139636653423200
L218:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+8], r11
# i_move_sd
    mov qword ptr [rbx], 401163
# line_I
# i_call_f
    call table_key/1
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L219
    mov ecx, 1
    call 139636653423200
L219:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# call_light_bif_be
    align 4
L220:
L221:
    long mov rcx, 9223372036854775807
    mov rax, 94068436606752
    lea rdx, qword ptr [L220]
# BIF: ets:insert/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L152
    ret
# label_L
label_34:
# line_I
# bif_map_get_jssd
    mov rdi, qword ptr [rbx+16]
    mov esi, 137291
    rex test dil, 1
    jne L223
    mov rax, qword ptr [rdi-2]
    and al, 63
    cmp al, 44
    short je L224
L223:
.db 0x0F, 0x1F, 0x00
    call 139636653423960
L224:
    call L225
    je L222
    mov rdi, qword ptr [rbx+16]
    mov esi, 137291
.db 0x66, 0x90
    call 139636653423920
L222:
    mov qword ptr [rbx+24], rax
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L226
    mov ecx, 4
    call 139636653423200
L226:
    sub rsp, 32
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+24], r10
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+24]
    cmp rsi, 779
    je label_39
    cmp rsi, 1291
    je label_37
    cmp rsi, 2251
    je label_43
    cmp rsi, 22027
    je label_38
    cmp rsi, 47563
    je label_35
    cmp rsi, 81611
    je label_41
    cmp rsi, 214667
    je label_36
    cmp rsi, 400203
    je label_40
    cmp rsi, 400267
    je label_44
    cmp rsi, 400331
    je label_42
    jmp label_46
# label_L
label_35:
# i_move_sd
    mov qword ptr [rsp], 79
# jump_f
    jmp label_45
# label_L
label_36:
# i_move_sd
    mov qword ptr [rsp], 95
# jump_f
    jmp label_45
# label_L
label_37:
# i_move_sd
    mov qword ptr [rsp], -1
# jump_f
    jmp label_45
# label_L
label_38:
# i_move_sd
    mov qword ptr [rsp], 111
# jump_f
    jmp label_45
# label_L
label_39:
# i_move_sd
    mov qword ptr [rsp], 63
# jump_f
    jmp label_45
# label_L
label_40:
# i_move_sd
    mov qword ptr [rsp], 15
# jump_f
    jmp label_45
# label_L
label_41:
# i_move_sd
    mov qword ptr [rsp], 127
# jump_f
    jmp label_45
# label_L
label_42:
# i_move_sd
    mov qword ptr [rsp], 47
# jump_f
    jmp label_45
# label_L
label_43:
# i_move_sd
    mov qword ptr [rsp], 175
# jump_f
    jmp label_45
# label_L
label_44:
# i_move_sd
    mov qword ptr [rsp], 31
# label_L
label_45:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call table_key/1
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L227
    mov ecx, 1
    call 139636653423200
L227:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 204683
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx+8], r11
# i_trim_t
    add rsp, 8
# call_light_bif_be
    align 4
L228:
L229:
    long mov rcx, 9223372036854775807
    mov rax, 94068435899424
    lea rdx, qword ptr [L228]
# BIF: persistent_term:put/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_47
# i_move_sd
    mov r10, qword ptr [rsp+8]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rsp+8], r11
# i_trim_t
    add rsp, 8
# line_I
# i_call_f
.db 0x90
    call table_key/1
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L230
    mov ecx, 1
    call 139636653423200
L230:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# call_light_bif_be
    align 4
L231:
L232:
    long mov rcx, 9223372036854775807
    mov rax, 94068436606752
    lea rdx, qword ptr [L231]
# BIF: ets:insert/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L152
    ret
# label_L
label_46:
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 32
    jmp '-inlined-level_to_int/1-'/1
# label_L
label_47:
# line_I
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L210
# i_func_label_L
    nop
    align 8
label_48:
# func_line_I
# i_func_info_IaaI
# logger_config:set/3
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
set/3:
# i_breakpoint_trampoline
    short jmp L233
.db 0x90
    call L144
L233:
# i_test_yield
    lea rdx, qword ptr [set/3+24]
    dec r14d
    long jle L145
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx+8], 401163
    jne label_50
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L234
    mov ecx, 3
.db 0x66, 0x90
    call 139636653423200
L234:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+8], r11
# i_move_sd
    mov qword ptr [rbx], 401163
# line_I
# i_call_f
    call table_key/1
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L235
    mov ecx, 1
    call 139636653423200
L235:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# i_trim_t
    add rsp, 16
# call_light_bif_be
    align 4
L236:
L237:
    long mov rcx, 9223372036854775807
    mov rax, 94068436606752
    lea rdx, qword ptr [L236]
# BIF: ets:insert/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L152
    ret
# label_L
label_50:
# line_I
# bif_map_get_jssd
    mov rdi, qword ptr [rbx+16]
    mov esi, 137291
    rex test dil, 1
    jne L239
    mov rax, qword ptr [rdi-2]
    and al, 63
    cmp al, 44
    short je L240
L239:
    call 139636653423960
L240:
    call L225
    je L238
    mov rdi, qword ptr [rbx+16]
    mov esi, 137291
.db 0x66, 0x90
    call 139636653423920
L238:
    mov qword ptr [rbx+24], rax
# allocate_tt
    lea rdx, qword ptr [r15+64]
    cmp rdx, rsp
    short jbe L241
    mov ecx, 4
    call 139636653423200
L241:
    sub rsp, 32
# init_yregs_I
    mov qword ptr [rsp], 59
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx+8], 1
    vmovups xmmword ptr [rsp+8], xmm0
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp+24], r10
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+24]
    cmp rsi, 779
    je label_55
    cmp rsi, 1291
    je label_53
    cmp rsi, 2251
    je label_59
    cmp rsi, 22027
    je label_54
    cmp rsi, 47563
    je label_51
    cmp rsi, 81611
    je label_57
    cmp rsi, 214667
    je label_52
    cmp rsi, 400203
    je label_56
    cmp rsi, 400267
    je label_60
    cmp rsi, 400331
    je label_58
    jmp label_63
# label_L
label_51:
# i_move_sd
    mov qword ptr [rsp], 79
# jump_f
    jmp label_61
# label_L
label_52:
# i_move_sd
    mov qword ptr [rsp], 95
# jump_f
    jmp label_61
# label_L
label_53:
# i_move_sd
    mov qword ptr [rsp], -1
# jump_f
    jmp label_61
# label_L
label_54:
# i_move_sd
    mov qword ptr [rsp], 111
# jump_f
    jmp label_61
# label_L
label_55:
# i_move_sd
    mov qword ptr [rsp], 63
# jump_f
    jmp label_61
# label_L
label_56:
# i_move_sd
    mov qword ptr [rsp], 15
# jump_f
    jmp label_61
# label_L
label_57:
# i_move_sd
    mov qword ptr [rsp], 127
# jump_f
    jmp label_61
# label_L
label_58:
# i_move_sd
    mov qword ptr [rsp], 47
# jump_f
    jmp label_61
# label_L
label_59:
# i_move_sd
    mov qword ptr [rsp], 175
# jump_f
    jmp label_61
# label_L
label_60:
# i_move_sd
    mov qword ptr [rsp], 31
# label_L
label_61:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call table_key/1
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L242
    mov ecx, 1
    call 139636653423200
L242:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 204683
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp]
    mov qword ptr [rbx+8], r11
# call_light_bif_be
    align 4
L243:
L244:
    long mov rcx, 9223372036854775807
    mov rax, 94068435899424
    lea rdx, qword ptr [L243]
# BIF: persistent_term:put/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 32075
    jne label_64
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rsp+16], 149707
    jne label_62
# line_I
# call_light_bif_be
    align 4
L245:
L246:
    long mov rcx, 9223372036854775807
    mov rax, 94068435901824
    lea rdx, qword ptr [L245]
# BIF: persistent_term:get/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# init_yregs_I
    mov qword ptr [rsp], 59
# i_call_f
.db 0x0F, 0x1F, 0x00
    call '-set/3-lc$^0/1-0-'/2
# label_L
label_62:
# i_move_sd
    mov r10, qword ptr [rsp+16]
    mov qword ptr [rbx], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rsp+16], r11
# i_trim_t
    add rsp, 16
# line_I
# i_call_f
.db 0x90
    call table_key/1
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L247
    mov ecx, 1
    call 139636653423200
L247:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+8], rdi
    mov rdi, qword ptr [rsp]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov r11, qword ptr [rsp+8]
    mov qword ptr [rbx], r11
# i_trim_t
    add rsp, 16
# call_light_bif_be
    align 4
L248:
L249:
    long mov rcx, 9223372036854775807
    mov rax, 94068436606752
    lea rdx, qword ptr [L248]
# BIF: ets:insert/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L152
    ret
# label_L
label_63:
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# i_call_last_ft
    add rsp, 32
    jmp '-inlined-level_to_int/1-'/1
# label_L
label_64:
# line_I
# badmatch_s
    mov rdi, qword ptr [rbx]
    mov qword ptr [r13+112], rdi
    mov qword ptr [r13+104], 5200
    call L210
# i_func_label_L
    nop
    align 8
label_65:
# func_line_I
# i_func_info_IaaI
# logger_config:set_module_level/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x21, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
set_module_level/2:
# i_breakpoint_trampoline
    short jmp L250
.db 0x90
    call L144
L250:
# i_test_yield
    lea rdx, qword ptr [set_module_level/2+24]
    dec r14d
    long jle L145
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L251
    mov ecx, 2
    call 139636653423200
L251:
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx+8]
    cmp rsi, 779
    je label_71
    cmp rsi, 1291
    je label_69
    cmp rsi, 2251
    je label_75
    cmp rsi, 22027
    je label_70
    cmp rsi, 47563
    je label_67
    cmp rsi, 81611
    je label_73
    cmp rsi, 214667
    je label_68
    cmp rsi, 400203
    je label_72
    cmp rsi, 400267
    je label_76
    cmp rsi, 400331
    je label_74
    jmp label_78
# label_L
label_67:
# i_move_sd
    mov qword ptr [rbx+8], 79
# jump_f
    jmp label_77
# label_L
label_68:
# i_move_sd
    mov qword ptr [rbx+8], 95
# jump_f
    jmp label_77
# label_L
label_69:
# i_move_sd
    mov qword ptr [rbx+8], -1
# jump_f
    jmp label_77
# label_L
label_70:
# i_move_sd
    mov qword ptr [rbx+8], 111
# jump_f
    jmp label_77
# label_L
label_71:
# i_move_sd
    mov qword ptr [rbx+8], 63
# jump_f
    jmp label_77
# label_L
label_72:
# i_move_sd
    mov qword ptr [rbx+8], 15
# jump_f
    jmp label_77
# label_L
label_73:
# i_move_sd
    mov qword ptr [rbx+8], 127
# jump_f
    jmp label_77
# label_L
label_74:
# i_move_sd
    mov qword ptr [rbx+8], 47
# jump_f
    jmp label_77
# label_L
label_75:
# i_move_sd
    mov qword ptr [rbx+8], 175
# jump_f
    jmp label_77
# label_L
label_76:
# i_move_sd
    mov qword ptr [rbx+8], 31
# label_L
label_77:
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call '-set_module_level/2-lc$^0/1-0-'/2
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L152
    ret
# label_L
label_78:
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rbx], r10
# i_call_last_ft
    jmp '-inlined-level_to_int/1-'/1
# i_func_label_L
    align 8
label_79:
# func_line_I
# i_func_info_IaaI
# logger_config:unset_module_level/1
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x22, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
unset_module_level/1:
# i_breakpoint_trampoline
    short jmp L252
.db 0x90
    call L144
L252:
# i_test_yield
    lea rdx, qword ptr [unset_module_level/1+24]
    dec r14d
    long jle L145
    align 4
# is_eq_exact_fss
# simplified check since one argument is an immediate
    cmp qword ptr [rbx], 2251
    jne label_81
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L253
    xor ecx, ecx
.db 0x66, 0x90
    call 139636653423200
L253:
    sub rsp, 8
# init_yregs_I
    mov qword ptr [rsp], 59
# i_move_sd
    mov qword ptr [rbx+8], 95
# i_move_sd
L254:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# call_light_bif_be
    align 4
L255:
L256:
    long mov rcx, 9223372036854775807
    mov rax, 94068435902592
    lea rdx, qword ptr [L255]
# BIF: persistent_term:get/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# line_I
# call_light_bif_be
    align 4
L257:
L258:
    long mov rcx, 9223372036854775807
    mov rax, 94068435901824
    lea rdx, qword ptr [L257]
# BIF: persistent_term:get/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_move_sd
    mov r10, qword ptr [rsp]
    mov qword ptr [rbx+8], r10
# i_trim_t
    add rsp, 8
# i_call_f
.db 0x0F, 0x1F, 0x00
    call '-unset_module_level/1-lc$^0/1-1-'/2
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L152
    ret
# label_L
label_81:
# allocate_tt
    lea rdx, qword ptr [r15+40]
    cmp rdx, rsp
    short jbe L259
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L259:
    sub rsp, 8
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rsp], r10
# i_move_sd
    mov qword ptr [rbx+8], 95
# i_move_sd
L260:
    long mov rdi, 9223372036854775807
    mov qword ptr [rbx], rdi
# line_I
# call_light_bif_be
    align 4
L261:
L262:
    long mov rcx, 9223372036854775807
    mov rax, 94068435902592
    lea rdx, qword ptr [L261]
# BIF: persistent_term:get/2
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
# i_call_f
.db 0x90
    call '-unset_module_level/1-lc$^1/1-0-'/2
# i_move_sd
    mov qword ptr [rbx], 32075
# deallocate_t
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_82:
# func_line_I
# i_func_info_IaaI
# logger_config:get_module_level/0
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x22, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
get_module_level/0:
# i_breakpoint_trampoline
    short jmp L263
.db 0x90
    call L144
L263:
# i_test_yield
    lea rdx, qword ptr [get_module_level/0+24]
    dec r14d
    long jle L145
    align 4
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L264
    xor ecx, ecx
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L264:
# line_I
# call_light_bif_be
    align 4
L265:
L266:
    long mov rcx, 9223372036854775807
    mov rax, 94068435901824
    lea rdx, qword ptr [L265]
# BIF: persistent_term:get/0
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_call_f
.db 0x0F, 0x1F, 0x00
    call '-get_module_level/0-lc$^0/1-0-'/1
# line_I
# i_call_ext_last_et
L267:
    long mov rax, 9223372036854775807
    jmp qword ptr [rax+r12*8]
# i_func_label_L
    align 8
label_84:
# func_line_I
# i_func_info_IaaI
# logger_config:level_to_int/1
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x23, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
level_to_int/1:
# i_breakpoint_trampoline
    short jmp L268
.db 0x90
    call L144
L268:
# i_test_yield
    lea rdx, qword ptr [level_to_int/1+24]
    dec r14d
    long jle L145
    align 4
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 779
    je label_90
    cmp rsi, 1291
    je label_88
    cmp rsi, 2251
    je label_94
    cmp rsi, 22027
    je label_89
    cmp rsi, 47563
    je label_86
    cmp rsi, 81611
    je label_92
    cmp rsi, 214667
    je label_87
    cmp rsi, 400203
    je label_91
    cmp rsi, 400267
    je label_95
    cmp rsi, 400331
    je label_93
    jmp label_84
# label_L
label_86:
# i_move_sd
    mov qword ptr [rbx], 79
# return
    dec r14d
    jl L152
    ret
# label_L
label_87:
# i_move_sd
    mov qword ptr [rbx], 95
# return
    dec r14d
    jl L152
    ret
# label_L
label_88:
# i_move_sd
    mov qword ptr [rbx], -1
# return
    dec r14d
    jl L152
    ret
# label_L
label_89:
# i_move_sd
    mov qword ptr [rbx], 111
# return
    dec r14d
    jl L152
    ret
# label_L
label_90:
# i_move_sd
    mov qword ptr [rbx], 63
# return
    dec r14d
    jl L152
    ret
# label_L
label_91:
# i_move_sd
    mov qword ptr [rbx], 15
# return
    dec r14d
    jl L152
    ret
# label_L
label_92:
# i_move_sd
    mov qword ptr [rbx], 127
# return
    dec r14d
    jl L152
    ret
# label_L
label_93:
# i_move_sd
    mov qword ptr [rbx], 47
# return
    dec r14d
    jl L152
    ret
# label_L
label_94:
# i_move_sd
    mov qword ptr [rbx], 175
# return
    dec r14d
    jl L152
    ret
# label_L
label_95:
# i_move_sd
    mov qword ptr [rbx], 31
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_96:
# func_line_I
# i_func_info_IaaI
# logger_config:int_to_level/1
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x52, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
int_to_level/1:
# i_breakpoint_trampoline
    short jmp L269
.db 0x90
    call L144
L269:
# i_test_yield
    lea rdx, qword ptr [int_to_level/1+24]
    dec r14d
    long jle L145
    align 4
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 15
    je label_106
    cmp rsi, 31
    je label_105
    cmp rsi, 47
    je label_104
    cmp rsi, 63
    je label_103
    cmp rsi, 79
    je label_102
    cmp rsi, 95
    je label_101
    cmp rsi, 111
    je label_100
    cmp rsi, 127
    je label_99
    cmp rsi, 175
    je label_98
    cmp rsi, -1
    je label_107
    jmp label_96
# label_L
label_98:
# i_move_sd
    mov qword ptr [rbx], 2251
# return
    dec r14d
    jl L152
    ret
# label_L
label_99:
# i_move_sd
    mov qword ptr [rbx], 81611
# return
    dec r14d
    jl L152
    ret
# label_L
label_100:
# i_move_sd
    mov qword ptr [rbx], 22027
# return
    dec r14d
    jl L152
    ret
# label_L
label_101:
# i_move_sd
    mov qword ptr [rbx], 214667
# return
    dec r14d
    jl L152
    ret
# label_L
label_102:
# i_move_sd
    mov qword ptr [rbx], 47563
# return
    dec r14d
    jl L152
    ret
# label_L
label_103:
# i_move_sd
    mov qword ptr [rbx], 779
# return
    dec r14d
    jl L152
    ret
# label_L
label_104:
# i_move_sd
    mov qword ptr [rbx], 400331
# return
    dec r14d
    jl L152
    ret
# label_L
label_105:
# i_move_sd
    mov qword ptr [rbx], 400267
# return
    dec r14d
    jl L152
    ret
# label_L
label_106:
# i_move_sd
    mov qword ptr [rbx], 400203
# return
    dec r14d
    jl L152
    ret
# label_L
label_107:
# i_move_sd
    mov qword ptr [rbx], 1291
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_108:
# func_line_I
# i_func_info_IaaI
# logger_config:table_key/1
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x52, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
table_key/1:
# i_breakpoint_trampoline
    short jmp L270
.db 0x90
    call L144
L270:
# i_test_yield
    lea rdx, qword ptr [table_key/1+24]
    dec r14d
    long jle L145
    align 4
# i_select_val_lins_sfI
    mov rsi, qword ptr [rbx]
    cmp rsi, 149707
    je label_111
    cmp rsi, 401163
    je label_110
    jmp label_112
# label_L
label_110:
# i_move_sd
    mov qword ptr [rbx], 414347
# return
    dec r14d
    jl L152
    ret
# label_L
label_111:
# i_move_sd
    mov qword ptr [rbx], 414411
# return
    dec r14d
    jl L152
    ret
# label_L
label_112:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L271
    mov ecx, 1
    call 139636653423200
L271:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 414475
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_113:
# func_line_I
# i_func_info_IaaI
# logger_config:module_info/0
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/0:
# i_breakpoint_trampoline
    short jmp L272
.db 0x90
    call L144
L272:
# i_test_yield
    lea rdx, qword ptr [module_info/0+24]
    dec r14d
    long jle L145
    align 4
# i_move_sd
    mov qword ptr [rbx], 204683
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L273
    mov ecx, 1
.db 0x90
    call 139636653423200
L273:
# call_light_bif_be
    align 4
L274:
L275:
    long mov rcx, 9223372036854775807
    mov rax, 94068435872048
    lea rdx, qword ptr [L274]
# BIF: erlang:get_module_info/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_115:
# func_line_I
# i_func_info_IaaI
# logger_config:module_info/1
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
module_info/1:
# i_breakpoint_trampoline
    short jmp L276
.db 0x90
    call L144
L276:
# i_test_yield
    lea rdx, qword ptr [module_info/1+24]
    dec r14d
    long jle L145
    align 4
# i_move_sd
    mov r10, qword ptr [rbx]
    mov qword ptr [rbx+8], r10
# i_move_sd
    mov qword ptr [rbx], 204683
# allocate_tt
    lea rdx, qword ptr [r15+32]
    cmp rdx, rsp
    short jbe L277
    mov ecx, 2
.db 0x66, 0x90
    call 139636653423200
L277:
# call_light_bif_be
    align 4
L278:
L279:
    long mov rcx, 9223372036854775807
    mov rax, 94068435873056
    lea rdx, qword ptr [L278]
# BIF: erlang:get_module_info/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# deallocate_t
# return
    dec r14d
    jl L152
    ret
# i_func_label_L
    align 8
label_117:
# func_line_I
# i_func_info_IaaI
# logger_config:'-get_module_level/0-lc$^0/1-0-'/1
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x53, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-get_module_level/0-lc$^0/1-0-'/1:
# i_breakpoint_trampoline
    short jmp L280
.db 0x90
    call L144
L280:
# i_test_yield
    lea rdx, qword ptr ['-get_module_level/0-lc$^0/1-0-'/1+24]
    dec r14d
    long jle L145
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_120
# (moving and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rax-1], 1
    vmovups xmmword ptr [rbx], xmm0
# i_is_tuple_of_arity_fsA
    mov rsi, qword ptr [rbx+8]
    rex test sil, 1
    jne label_119
    cmp dword ptr [rsi-2], 128
    jne label_119
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# i_is_tagged_tuple_fsAa
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_119
    cmp dword ptr [rsi-2], 128
    jne label_119
    cmp qword ptr [rsi+6], 204683
    jne label_119
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+16], r11
# is_atom_fs
# simplified fetching of BEAM register
    mov rax, r11
    and al, 63
    cmp al, 11
    jne label_119
# is_ne_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r11, 414411
    je label_119
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+8]
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+14]
    mov qword ptr [rbx+8], r10
# is_lt_fss
# simplified fetching of BEAM register
    mov rsi, r10
    mov edi, 175
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L281
    cmp rdi, rsi
    short jmp L282
L281:
    call L174
L282:
    jge label_119
L283:
# line_I
# i_minus_ssjd
    mov rsi, qword ptr [rbx+8]
    mov edx, 271
# is the operand small?
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L285
# skipped overflow test because the result is always small
    mov rax, rsi
    sub rax, 256
    short jmp L284
L285:
    call L177
L284:
    mov qword ptr [rbx+8], rax
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L286
    mov ecx, 3
    call 139636653423200
L286:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rsp], r10
# i_move_sd
    mov r11, qword ptr [rbx]
    mov qword ptr [rsp+8], r11
# i_move_sd
    mov rdx, qword ptr [rbx+8]
    mov qword ptr [rbx], rdx
# i_call_f
    call int_to_level/1
# swap_dd
    mov rdi, qword ptr [rsp+8]
    mov rsi, qword ptr [rbx]
    mov qword ptr [rbx], rdi
    mov qword ptr [rsp+8], rsi
# line_I
# i_call_f
.db 0x0F, 0x1F, 0x00
    call '-get_module_level/0-lc$^0/1-0-'/1
# test_heap_It
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L287
    mov ecx, 1
    call 139636653423200
L287:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
# (moving two elements at once)
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [r15+8], xmm0
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx+8], r10
# put_cons_ss
# (putting and swapping head and tail together)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [r15], xmm0
    lea rsi, qword ptr [r15+1]
# store_cons_Id
    add r15, 16
    mov qword ptr [rbx], rsi
# deallocate_t
    add rsp, 16
# return
    dec r14d
    jl L152
    ret
# label_L
label_119:
# i_call_only_f
    jmp '-get_module_level/0-lc$^0/1-0-'/1
# label_L
label_120:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_121
# return
    dec r14d
    jl L152
    ret
# label_L
label_121:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L288
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L288:
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
    short jbe L289
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L289:
# call_light_bif_be
    align 4
L290:
L291:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L290]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_122:
# func_line_I
# i_func_info_IaaI
# logger_config:'-unset_module_level/1-lc$^1/1-0-'/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x53, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-unset_module_level/1-lc$^1/1-0-'/2:
# i_breakpoint_trampoline
    short jmp L292
.db 0x90
    call L144
L292:
# i_test_yield
    lea rdx, qword ptr ['-unset_module_level/1-lc$^1/1-0-'/2+24]
    dec r14d
    long jle L145
    align 4
# is_nonempty_list_fS
    test byte ptr [rbx], 2
    jne label_124
# allocate_heap_tIt
    lea rdx, qword ptr [r15+72]
    cmp rdx, rsp
    short jbe L293
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L293:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+8], r10
# get_list_Sdd
    mov rdi, qword ptr [rbx]
    mov rsi, qword ptr [rdi-1]
    mov rdx, qword ptr [rdi+7]
    mov qword ptr [rbx], rsi
    mov qword ptr [rsp], rdx
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 204683
# simplified fetching of BEAM register
    mov rdi, rsi
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r11, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r11
# call_light_bif_be
    align 4
L294:
L295:
    long mov rcx, 9223372036854775807
    mov rax, 94068435899424
    lea rdx, qword ptr [L294]
# BIF: persistent_term:put/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 16
    jmp '-unset_module_level/1-lc$^1/1-0-'/2
# label_L
label_124:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_125
# return
    dec r14d
    jl L152
    ret
# label_L
label_125:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L296
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L296:
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
    short jbe L297
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L297:
# call_light_bif_be
    align 4
L298:
L299:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L298]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_126:
# func_line_I
# i_func_info_IaaI
# logger_config:'-unset_module_level/1-lc$^0/1-1-'/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCB, 0x53, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-unset_module_level/1-lc$^0/1-1-'/2:
# i_breakpoint_trampoline
    short jmp L300
.db 0x90
    call L144
L300:
# i_test_yield
    lea rdx, qword ptr ['-unset_module_level/1-lc$^0/1-1-'/2+24]
    dec r14d
    long jle L145
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_129
    mov rsi, qword ptr [rax-1]
    mov rdx, qword ptr [rax+7]
    mov qword ptr [rbx+16], rsi
    mov qword ptr [rbx], rdx
# i_is_tuple_of_arity_fsA
# skipped fetching of BEAM register
    rex test sil, 1
    jne label_128
    cmp dword ptr [rsi-2], 128
    jne label_128
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+16], r10
# i_is_tagged_tuple_fsAa
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_128
    cmp dword ptr [rsi-2], 128
    jne label_128
    cmp qword ptr [rsi+6], 204683
    jne label_128
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+24], r11
# is_atom_fs
# simplified fetching of BEAM register
    mov rax, r11
    and al, 63
    cmp al, 11
    jne label_128
# is_ne_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r11, 414411
    je label_128
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L301
    mov ecx, 3
.db 0x90
    call 139636653423200
L301:
    sub rsp, 16
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rbx]
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+16]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L302:
L303:
    long mov rcx, 9223372036854775807
    mov rax, 94068435899424
    lea rdx, qword ptr [L302]
# BIF: persistent_term:put/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 16
    jmp '-unset_module_level/1-lc$^0/1-1-'/2
# label_L
label_128:
# i_call_only_f
    jmp '-unset_module_level/1-lc$^0/1-1-'/2
# label_L
label_129:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_130
# return
    dec r14d
    jl L152
    ret
# label_L
label_130:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L304
    mov ecx, 1
.db 0x66, 0x90
    call 139636653423200
L304:
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
    short jbe L305
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L305:
# call_light_bif_be
    align 4
L306:
L307:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L306]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_131:
# func_line_I
# i_func_info_IaaI
# logger_config:'-set_module_level/2-lc$^0/1-0-'/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x54, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-set_module_level/2-lc$^0/1-0-'/2:
# i_breakpoint_trampoline
    short jmp L308
.db 0x90
    call L144
L308:
# i_test_yield
    lea rdx, qword ptr ['-set_module_level/2-lc$^0/1-0-'/2+24]
    dec r14d
    long jle L145
    align 4
# is_nonempty_list_fS
    test byte ptr [rbx], 2
    jne label_133
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L309
    mov ecx, 2
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L309:
    sub rsp, 16
# i_move_sd
    mov r10, qword ptr [rbx+8]
    mov qword ptr [rsp+8], r10
# get_list_Sdd
    mov rdi, qword ptr [rbx]
    mov rsi, qword ptr [rdi-1]
    mov rdx, qword ptr [rdi+7]
    mov qword ptr [rbx], rsi
    mov qword ptr [rsp], rdx
# i_plus_ssjd
# add without overflow check
# simplified fetching of BEAM register
    mov rax, r10
    add rax, 256
    mov qword ptr [rbx+8], rax
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L310
    mov ecx, 2
    call 139636653423200
L310:
# put_tuple2_SA
# Move arity word
    mov qword ptr [r15], 128
# Move tuple data
    mov qword ptr [r15+8], 204683
    mov rdi, qword ptr [rbx]
    mov qword ptr [r15+16], rdi
# Create boxed ptr
    lea r10, qword ptr [r15+2]
    add r15, 24
    mov qword ptr [rbx], r10
# call_light_bif_be
    align 4
L311:
L312:
    long mov rcx, 9223372036854775807
    mov rax, 94068435899424
    lea rdx, qword ptr [L311]
# BIF: persistent_term:put/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# move_two_words_sdsd
    vmovups xmm0, xmmword ptr [rsp]
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 16
    jmp '-set_module_level/2-lc$^0/1-0-'/2
# label_L
label_133:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_134
# return
    dec r14d
    jl L152
    ret
# label_L
label_134:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L313
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L313:
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
    short jbe L314
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L314:
# call_light_bif_be
    align 4
L315:
L316:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L315]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_135:
# func_line_I
# i_func_info_IaaI
# logger_config:'-set/3-lc$^0/1-0-'/2
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4B, 0x54, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-set/3-lc$^0/1-0-'/2:
# i_breakpoint_trampoline
    short jmp L317
.db 0x90
    call L144
L317:
# i_test_yield
    lea rdx, qword ptr ['-set/3-lc$^0/1-0-'/2+24]
    dec r14d
    long jle L145
    align 4
# is_nonempty_list_get_list_fSdd
    mov rax, qword ptr [rbx]
    test al, 2
    jne label_138
    mov rsi, qword ptr [rax-1]
    mov rdx, qword ptr [rax+7]
    mov qword ptr [rbx+16], rsi
    mov qword ptr [rbx], rdx
# i_is_tuple_of_arity_fsA
# skipped fetching of BEAM register
    rex test sil, 1
    jne label_137
    cmp dword ptr [rsi-2], 128
    jne label_137
# i_get_tuple_element_sPS
    mov r10, qword ptr [rsi+6]
    mov qword ptr [rbx+24], r10
# i_is_tagged_tuple_fsAa
# simplified fetching of BEAM register
    mov rsi, r10
    rex test sil, 1
    jne label_137
    cmp dword ptr [rsi-2], 128
    jne label_137
    cmp qword ptr [rsi+6], 204683
    jne label_137
# i_get_tuple_element_sPS
    mov r11, qword ptr [rsi+14]
    mov qword ptr [rbx+32], r11
# is_atom_fs
# simplified fetching of BEAM register
    mov rax, r11
    and al, 63
    cmp al, 11
    jne label_137
# is_ne_exact_fss
# simplified check since one argument is an immediate
# simplified compare of BEAM register
    cmp r11, 414411
    je label_137
# load_tuple_ptr_s
    mov rsi, qword ptr [rbx+16]
# i_get_tuple_element_sPS
    mov rcx, qword ptr [rsi+14]
    mov qword ptr [rbx+16], rcx
# is_ge_fss
# simplified fetching of BEAM register
    mov rsi, rcx
    mov edi, 175
    mov eax, esi
    and al, 15
    cmp al, 15
    short jne L318
L319:
    cmp rdi, rsi
    short jmp L320
L318:
    call L174
L320:
    jl label_137
L321:
# allocate_tt
    lea rdx, qword ptr [r15+48]
    cmp rdx, rsp
    short jbe L322
    mov ecx, 4
.db 0x90
    call 139636653423200
L322:
    sub rsp, 16
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rbx], 1
    vmovups xmmword ptr [rsp], xmm0
# i_move_sd
    mov r10, qword ptr [rbx+24]
    mov qword ptr [rbx], r10
# line_I
# call_light_bif_be
    align 4
L323:
L324:
    long mov rcx, 9223372036854775807
    mov rax, 94068435899424
    lea rdx, qword ptr [L323]
# BIF: persistent_term:put/2
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# move_two_words_sdsd
# (moving and swapping)
    vpermilpd xmm0, xmmword ptr [rsp], 1
    vmovups xmmword ptr [rbx], xmm0
# i_call_last_ft
    add rsp, 16
    jmp '-set/3-lc$^0/1-0-'/2
# label_L
label_137:
# i_call_only_f
    jmp '-set/3-lc$^0/1-0-'/2
# label_L
label_138:
# is_nil_fS
    cmp byte ptr [rbx], 59
    jne label_139
# return
    dec r14d
    jl L152
    ret
# label_L
label_139:
# test_heap_It
    lea rdx, qword ptr [r15+56]
    cmp rdx, rsp
    short jbe L325
    mov ecx, 1
    call 139636653423200
L325:
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
    short jbe L326
    mov ecx, 1
.db 0x0F, 0x1F, 0x00
    call 139636653423200
L326:
# call_light_bif_be
    align 4
L327:
L328:
    long mov rcx, 9223372036854775807
    mov rax, 94068436090432
    lea rdx, qword ptr [L327]
# BIF: erlang:error/1
.db 0x0F, 0x1F, 0x00
    call 139636653421952
# i_func_label_L
    align 8
label_140:
# func_line_I
# i_func_info_IaaI
# logger_config:'-inlined-level_to_int/1-'/1
    call L142
    nop
    nop
.db 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x8B, 0x1F, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8B, 0x54, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
# aligned_label_Lt
    align 4
'-inlined-level_to_int/1-'/1:
# i_breakpoint_trampoline
    short jmp L329
.db 0x90
    call L144
L329:
# i_test_yield
    lea rdx, qword ptr ['-inlined-level_to_int/1-'/1+24]
    dec r14d
    long jle L145
    align 4
# jump_f
    short jmp label_140
# int_code_end
L330:
    mov rbp, rsp
    lea rsp, qword ptr [rbx-64]
    vzeroupper
    mov rdi, 94068440830267
    call 94068434741248
L210:
    jmp 139636653427776
L177:
    jmp 139636653426736
L174:
    jmp 139636653420712
L152:
    jmp 139636653422960
L225:
    jmp 139636653424896
L145:
    jmp 139636653426040
L144:
    jmp 139636653424496
L142:
    jmp 139636653424856
.section .rodata {#1}
line:
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.section .text {#0}
.section .rodata {#1}
attr:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x68, 0x02, 0x77, 0x03, 0x76, 0x73, 0x6E, 0x6C, 0x00, 0x00, 0x00, 0x01, 0x6E, 0x10, 0x00, 0xE5, 0x0F, 0xDF, 0xFE, 0x89, 0x12, 0xEC, 0xA5, 0x9A, 0xED, 0x8B, 0x76, 0xF7, 0x5B, 0x09, 0x4A, 0x6A, 0x6A
.section .text {#0}
.section .rodata {#1}
compile:
.db 0x83, 0x6C, 0x00, 0x00, 0x00, 0x03, 0x68, 0x02, 0x77, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x6B, 0x00, 0x05, 0x38, 0x2E, 0x36, 0x2E, 0x31, 0x68, 0x02, 0x77, 0x07, 0x6F, 0x70, 0x74, 0x69, 0x6F, 0x6E, 0x73, 0x6C, 0x00, 0x00, 0x00, 0x06, 0x77, 0x0A, 0x64, 0x65, 0x62, 0x75, 0x67, 0x5F, 0x69, 0x6E, 0x66, 0x6F, 0x68, 0x02, 0x77, 0x01, 0x69, 0x6B, 0x00, 0x28, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x2E, 0x2E, 0x2F, 0x69, 0x6E, 0x63, 0x6C, 0x75, 0x64, 0x65, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x66, 0x75, 0x6E, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x77, 0x19, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x64, 0x6F, 0x63, 0x5F, 0x63, 0x61, 0x6C, 0x6C, 0x62, 0x61, 0x63, 0x6B, 0x77, 0x1C, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x6D, 0x69, 0x73, 0x73, 0x69, 0x6E, 0x67, 0x5F, 0x73, 0x70, 0x65, 0x63, 0x5F, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, 0x65, 0x64, 0x77, 0x15, 0x77, 0x61, 0x72, 0x6E, 0x5F, 0x64, 0x65, 0x70, 0x72, 0x65, 0x63, 0x61, 0x74, 0x65, 0x64, 0x5F, 0x63, 0x61, 0x74, 0x63, 0x68, 0x6A, 0x68, 0x02, 0x77, 0x06, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x6B, 0x00, 0x2F, 0x2F, 0x62, 0x75, 0x69, 0x6C, 0x64, 0x72, 0x6F, 0x6F, 0x74, 0x2F, 0x6F, 0x74, 0x70, 0x2F, 0x6C, 0x69, 0x62, 0x2F, 0x6B, 0x65, 0x72, 0x6E, 0x65, 0x6C, 0x2F, 0x73, 0x72, 0x63, 0x2F, 0x6C, 0x6F, 0x67, 0x67, 0x65, 0x72, 0x5F, 0x63, 0x6F, 0x6E, 0x66, 0x69, 0x67, 0x2E, 0x65, 0x72, 0x6C, 0x6A
.section .text {#0}
.section .rodata {#1}
md5:
.db 0x4A, 0x09, 0x5B, 0xF7, 0x76, 0x8B, 0xED, 0x9A, 0xA5, 0xEC, 0x12, 0x89, 0xFE, 0xDF, 0x0F, 0xE5
.section .text {#0}
