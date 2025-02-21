section .data
msg_single     db "Programa carregado no bloco:", 10, 0
msg_multi      db "Programa carregado em multiplos blocos:", 10, 0
msg_block      db "Bloco %d: Endereco inicial: %d, Endereco final: %d", 10, 0
msg_range      db "Endereco inicial: %d, Endereco final: %d", 10, 0
msg_error      db "Erro: Nao ha espaco suficiente para carregar o programa.", 10, 0
msg_remaining  db "Erro: Nao ha espaco suficiente para carregar o restante do programa (%d unidades restantes).", 10, 0

section .bss
array    resd 40    ; Espaço para até 5 pares (endereco, tamanho)

section .text
global f1
global f2
extern printf

; f1: Processa os blocos disponíveis e armazena no array cada segmento a ser usado.
; Parâmetros:
;   [ebp+8]  -> tamanho do programa
;   [ebp+12] -> número de blocos (count)
;   [ebp+16] -> bloco 1: endereço
;   [ebp+20] -> bloco 1: tamanho
;   [ebp+24] -> bloco 2: endereço
;   [ebp+28] -> bloco 2: tamanho
;   ... etc.
f1:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov ecx, [ebp+8]     ; ecx = tamanho do programa restante
    xor esi, esi         ; esi = número de segmentos usados (inicialmente 0)
    xor edi, edi         ; edi = índice dos blocos (para acessar os argumentos)

.process_blocks:
    cmp edi, dword [ebp+12]  ; Se já processou todos os blocos, termina
    jge .done
    test ecx, ecx        ; Se não há mais espaço a alocar, termina
    jle .done

    ; Calcula o offset para o bloco atual (cada bloco ocupa 8 bytes)
    mov eax, edi
    shl eax, 3           ; eax = edi * 8
    mov ebx, [ebp+16+eax] ; ebx = endereço do bloco atual
    mov edx, [ebp+20+eax] ; edx = tamanho disponível no bloco

    ; Aloca o menor valor entre o tamanho do bloco (edx) e o restante do programa (ecx)
    cmp ecx, edx
    jl .use_remaining    ; se ecx < edx, usa apenas o que falta
    mov eax, edx         ; caso contrário, usa o bloco inteiro
    jmp .store_allocation
.use_remaining:
    mov eax, ecx         ; usa só o restante

.store_allocation:
    mov [array+esi*8], ebx   ; armazena o endereço do bloco
    mov [array+esi*8+4], eax ; armazena a quantidade a usar neste bloco
    sub ecx, eax             ; diminui o restante do programa
    inc esi                ; incrementa os segmentos usados
    inc edi                ; passa para o próximo bloco
    jmp .process_blocks

.done:
    ; Chama f2 com os parâmetros na ordem correta (cdecl):
    ; f2(segmentsUsed, array pointer, remaining)
    push ecx              ; 3º parâmetro: restante (se > 0, houve falta de espaço)
    push dword array      ; 2º parâmetro: ponteiro para o array de alocações
    push esi              ; 1º parâmetro: número de segmentos usados
    call f2
    add esp, 12

    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

; f2: Exibe as mensagens conforme os segmentos alocados e o restante.
; Parâmetros (cdecl):
;   [ebp+8]  -> número de segmentos usados
;   [ebp+12] -> ponteiro para o array de alocações
;   [ebp+16] -> restante (unidades que não foram alocadas)
f2:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; Lê o número de segmentos usados (primeiro parâmetro)
    mov eax, [ebp+8]
    test eax, eax
    jz .print_error

    cmp eax, 1
    jne .print_multi

    ; Caso de bloco único:
    push msg_single
    call printf
    add esp, 4

    ; Lê o ponteiro para o array (segundo parâmetro)
    mov edx, [ebp+12]
    mov eax, [edx]       ; endereço inicial do bloco
    mov ebx, [edx+4]     ; tamanho alocado
    dec ebx             ; (tamanho - 1)
    add ebx, eax        ; calcula endereço final

    push ebx            ; endereço final
    push eax            ; endereço inicial
    push msg_range
    call printf
    add esp, 12
    jmp .check_remaining

.print_multi:
    push msg_multi
    call printf
    add esp, 4

    xor esi, esi
.print_blocks:
    cmp esi, [ebp+8]    ; itera sobre os segmentos usados
    jge .check_remaining

    mov edx, [ebp+12]         ; ponteiro para o array
    mov eax, [edx+esi*8]      ; endereço inicial do segmento
    mov ebx, [edx+esi*8+4]    ; tamanho alocado no segmento
    dec ebx                 ; (tamanho - 1)
    add ebx, eax            ; calcula endereço final

    push ebx                ; endereço final
    push eax                ; endereço inicial
    lea eax, [esi+1]        ; número do bloco (base 1)
    push eax
    push msg_block
    call printf
    add esp, 16

    inc esi
    jmp .print_blocks

.check_remaining:
    mov eax, [ebp+16]    ; lê o restante (terceiro parâmetro)
    test eax, eax
    jz .done

    push eax
    push msg_remaining
    call printf
    add esp, 8
    jmp .done

.print_error:
    push msg_error
    call printf
    add esp, 4

.done:
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret
