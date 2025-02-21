section .data
; Mensagens (divididas em partes para montagem manual das linhas)
msg_single           db "Programa carregado no bloco:",10,0
msg_multi            db "Programa carregado em multiplos blocos:",10,0
msg_range_prefix     db "Endereco inicial: ",0
msg_range_mid        db ", Endereco final: ",0
msg_block_prefix     db "Bloco ",0
msg_block_mid        db ": Endereco inicial: ",0
msg_block_end        db ", Endereco final: ",0
msg_error            db "Erro: Nao ha espaco suficiente para carregar o programa.",10,0
msg_remaining_prefix db "Erro: Nao ha espaco suficiente para carregar o restante do programa (",0
msg_remaining_suffix db " unidades restantes).",10,0
newline              db 10,0
zero_str             db "0",0

section .bss
array       resd 40       ; Espaço para até 5 pares (endereço, tamanho)
num_buffer  resb 12       ; Buffer para conversão de inteiros (até 11 dígitos + terminador)

section .text
global f1
global f2

; f1:
; Recebe os seguintes parâmetros (cdecl):
;   [ebp+8]  = tamanho do programa a ser carregado
;   [ebp+12] = número de blocos (count)
;   [ebp+16] = bloco 1: endereço
;   [ebp+20] = bloco 1: tamanho
;   [ebp+24] = bloco 2: endereço
;   [ebp+28] = bloco 2: tamanho
;   ... etc.
f1:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov ecx, [ebp+8]     ; ecx = tamanho do programa restante
    xor esi, esi         ; esi = número de segmentos utilizados (inicialmente 0)
    xor edi, edi         ; edi = índice dos blocos (para acessar os argumentos)

.process_blocks:
    cmp edi, dword [ebp+12]
    jge .done
    test ecx, ecx
    jle .done

    ; Calcula offset para o bloco atual (cada bloco ocupa 8 bytes)
    mov eax, edi
    shl eax, 3           ; offset = edi * 8
    mov ebx, [ebp+16+eax] ; ebx = endereço do bloco atual
    mov edx, [ebp+20+eax] ; edx = tamanho disponível no bloco

    ; Aloca o menor valor entre o tamanho do bloco (edx) e o restante (ecx)
    cmp ecx, edx
    jl .use_remaining
    mov eax, edx         ; usa o bloco inteiro
    jmp .store_allocation
.use_remaining:
    mov eax, ecx         ; usa só o que falta
.store_allocation:
    mov [array+esi*8], ebx   ; grava endereço do bloco no array
    mov [array+esi*8+4], eax ; grava o tamanho que será usado neste bloco
    sub ecx, eax             ; diminui o restante
    inc esi                ; incrementa segmentos usados
    inc edi                ; passa para o próximo bloco
    jmp .process_blocks

.done:
    ; Chama f2 com os parâmetros: (segmentsUsed, array pointer, remaining)
    push ecx              ; 3º parâmetro: restante (se > 0, indica erro)
    push dword array      ; 2º parâmetro: ponteiro para o array
    push esi              ; 1º parâmetro: número de segmentos utilizados
    call f2
    add esp, 12

    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

; f2:
; Recebe (cdecl):
;   [ebp+8]  = número de segmentos utilizados
;   [ebp+12] = ponteiro para o array de alocações
;   [ebp+16] = restante (unidades que não foram alocadas)
f2:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov eax, [ebp+8]   ; número de segmentos usados
    test eax, eax
    jz .print_error

    cmp eax, 1
    je .single_case

    ; Caso múltiplos blocos
    mov eax, msg_multi
    call print_string

    xor esi, esi
.loop_segments:
    cmp esi, [ebp+8]         ; itera de 0 a (segmentsUsed - 1)
    jge .check_remaining

    mov edx, [ebp+12]        ; ponteiro para o array
    mov eax, [edx + esi*8]     ; endereço inicial do segmento
    mov edi, eax             ; guarda o endereço inicial
    mov ebx, [edx + esi*8+4]   ; tamanho alocado para este segmento
    mov ecx, ebx
    dec ecx                  ; endereço final = inicio + tamanho - 1
    add ecx, edi

    ; Imprime: "Bloco "
    mov eax, msg_block_prefix
    call print_string

    ; Imprime número do bloco (esi+1)
    mov eax, esi
    inc eax
    call print_int

    ; Imprime ": Endereco inicial: "
    mov eax, msg_block_mid
    call print_string

    ; Imprime endereço inicial (edi)
    mov eax, edi
    call print_int

    ; Imprime ", Endereco final: "
    mov eax, msg_block_end
    call print_string

    ; Imprime endereço final (ecx)
    mov eax, ecx
    call print_int

    ; Imprime nova linha
    mov eax, newline
    call print_string

    inc esi
    jmp .loop_segments

.single_case:
    ; Caso único: imprime "Programa carregado no bloco:"
    mov eax, msg_single
    call print_string

    ; Imprime "Endereco inicial: "
    mov eax, msg_range_prefix
    call print_string

    ; Recupera endereço inicial do primeiro bloco
    mov edx, [ebp+12]        ; ponteiro para o array
    mov eax, [edx]           ; endereço inicial do bloco
    call print_int

    ; Imprime ", Endereco final: "
    mov eax, msg_range_mid
    call print_string

    ; Calcula endereço final = inicio + tamanho - 1
    mov ebx, [edx+4]         ; tamanho alocado
    mov ecx, [edx]           ; endereço inicial
    add ecx, ebx
    dec ecx
    mov eax, ecx
    call print_int

    ; Imprime nova linha
    mov eax, newline
    call print_string

.check_remaining:
    mov eax, [ebp+16]        ; restante
    test eax, eax
    jz .done
    ; Se houver restante, imprime mensagem de erro
    mov eax, msg_remaining_prefix
    call print_string
    mov eax, [ebp+16]
    call print_int
    mov eax, msg_remaining_suffix
    call print_string
    jmp .done

.print_error:
    mov eax, msg_error
    call print_string
    jmp .done

.done:
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

;----------------------------------------
; Funções Auxiliares usando sys_write
;----------------------------------------

; print_string:
; Entrada: ponteiro para string nula-terminada em EAX.
; Calcula o tamanho e chama a sys_write (fd 1 = stdout).
print_string:
    push ebx
    push ecx
    push edx
    mov ecx, eax         ; ponteiro para a string
    xor edx, edx         ; contador de bytes = 0
.str_loop:
    cmp byte [ecx+edx], 0
    je .str_done
    inc edx
    jmp .str_loop
.str_done:
    mov ebx, 1           ; fd = stdout
    mov eax, 4           ; sys_write
    int 0x80
    pop edx
    pop ecx
    pop ebx
    ret

; print_int:
; Converte o inteiro em EAX para string e imprime-o.
; Usa o buffer num_buffer. Suporta apenas inteiros positivos.
print_int:
    push ebx
    push ecx
    push edx
    push esi
    cmp eax, 0
    jne .convert
    mov eax, zero_str
    call print_string
    jmp .print_int_end
.convert:
    mov esi, eax         ;
    mov edi, num_buffer + 11
    mov byte [edi], 0    
.convert_loop:
    xor edx, edx
    mov eax, esi
    mov ecx, 10
    div ecx              
    add dl, '0'
    dec edi
    mov [edi], dl
    mov esi, eax
    test esi, esi
    jnz .convert_loop
    mov eax, edi         
    call print_string
.print_int_end:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
