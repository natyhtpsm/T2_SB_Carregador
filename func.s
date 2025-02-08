section .data
fmt_prog:       db "Programa de %d bytes.", 10, 0
alloc_header:   db "Alocacao realizada:", 10, 0
fmt_alloc:      db "Segmento %d - Endereco: %d, Bytes alocados: %d", 10, 0
fmt_error:      db "ERRO: O programa nao coube totalmente na memoria livre. Faltam %d bytes para completar a carga.", 10, 0
fmt_success:    db "Programa carregado com sucesso em sua totalidade.", 10, 0

section .text
global _f1          
global _f2          

extern _printf       

; ----------------------------------------------------------
; f1: simula o carregamento do programa nos blocos disponíveis.
; Parâmetros:
;   [ebp+8]  : programSize (tamanho do programa, em bytes)
;   [ebp+12] : count (número de blocos)
;   [ebp+16] : primeiro bloco (addr1)
;   [ebp+20] : primeiro bloco (size1)
;   etc ...
;
; f1 faz o seguinte:
;   1. Armazena o valor de count em um local (em [ebp-8]) e inicializa segmentsCount em [ebp-4] com 0.
;   2. Reserva espaço para um array de registros (cada registro ocupa 8 bytes) = count*8.
;   3. Para cada bloco (índice em ESI), se ainda houver bytes restantes:
;        - Lê o endereço e o tamanho do bloco.
;        - Calcula allocated = (remaining <= blockSize) ? remaining : blockSize.
;        - Armazena no array o registro: [endereço, allocated].
;        - Decrementa remaining em allocated.
;   4. Chama f2 com os parâmetros:
;        (programSize, segmentsCount, pointer para array, remaining)
; ----------------------------------------------------------
_f1:                
    push ebp                ; salvar base pointer
    mov ebp, esp            ; configurar frame
    push ebx                ; salvar registradores
    push esi
    push edi

    ; reservar 8 bytes para dois locais: [ebp-8] = countCopy e [ebp-4] = segmentsCount
    sub esp, 8

    ; armazenar count (parâmetro em [ebp+12]) em [ebp-8]
    mov eax, [ebp+12]       ; eax = count
    mov [ebp-8], eax        ; countCopy = count

    ; inicializar segmentsCount = 0 em [ebp-4]
    mov dword [ebp-4], 0

    ; carregar programSize em eax (remaining)
    mov eax, [ebp+8]        ; eax = programSize

    ; calcular tamanho do array de registros = countCopy * 8
    mov ecx, [ebp-8]        ; ecx = countCopy
    mov ebx, 8              ; ebx = 8
    mov eax, ecx            ; eax = countCopy
    mul ebx                 ; eax = countCopy * 8 (mul usa EAX * EBX)
    ; reservar espaço para o array na pilha
    sub esp, eax            ; alocar array (tamanho = countCopy*8)
    mov edi, esp            ; edi aponta para o array de registros

    ; restaurar remaining (programSize) em eax
    mov eax, [ebp+8]        ; eax = remaining

    ; inicializar índice de loop (bloco) em ESI = 0
    xor esi, esi            ; esi = 0

.loop_f1:
    ; comparar índice (ESI) com countCopy (local em [ebp-8])
    mov ecx, [ebp-8]        ; ecx = countCopy
    cmp esi, ecx
    jge .after_loop         ; se esi >= countCopy, sair do loop

    ; verificar se remaining (em eax) é 0
    cmp eax, 0
    je .after_loop

    ; salvar remaining atual para uso após o cálculo (push)
    push eax                ; salva remaining

    ; ler os argumentos do bloco corrente:
    ; block address: em [ebp+16 + esi*8]
    mov edx, [ebp+16 + esi*8]   ; edx = block address

    ; block size: em [ebp+20 + esi*8]
    mov ebx, [ebp+20 + esi*8]   ; ebx = block size

    ; comparar remaining (na pilha, mas pop abaixo) com block size
    cmp eax, ebx
    jle .use_remaining        ; se remaining <= block size, usar remaining
    ; caso contrário, allocated = block size (já está em EBX)
    jmp .store_alloc
.use_remaining:
    ; allocated = remaining; mover eax (remaining) para EBX
    mov ebx, eax
.store_alloc:
    ; calcular a posição para armazenar o registro:
    ; usar segmentsCount (local em [ebp-4]); multiplicar por 8.
    mov edx, [ebp-4]       ; edx = segmentsCount
    mov eax, edx           ; eax = segmentsCount
    mov ecx, 8             ; ecx = 8
    mul ecx                ; eax = segmentsCount * 8
    add eax, edi           ; eax = endereço do registro atual no array

    ; armazenar o block address no registro (primeiros 4 bytes)
    ; recarregar block address (para garantir) de [ebp+16 + esi*8]
    mov edx, [ebp+16 + esi*8]   ; edx = block address
    mov [eax], edx         ; guardar block address

    ; armazenar o valor allocated (em EBX) no registro (próximos 4 bytes)
    mov [eax+4], ebx

    ; recuperar o valor original de remaining (pop) em ECX
    pop ecx                ; ecx = remaining antes do cálculo
    sub ecx, ebx           ; remaining = remaining - allocated
    mov eax, ecx           ; atualizar remaining em EAX

    ; incrementar segmentsCount (local em [ebp-4])
    mov ecx, [ebp-4]       ; ecx = segmentsCount
    add ecx, 1             ; ecx = segmentsCount + 1
    mov [ebp-4], ecx       ; atualizar segmentsCount

    ; incrementar o índice de loop (ESI)
    add esi, 1
    jmp .loop_f1

.after_loop:
    ; preparar a chamada a f2:
    ; f2(programSize, segmentsCount, pointer para array, remaining)
    push eax               ; push remaining (em EAX)
    mov eax, [ebp-4]       ; eax = segmentsCount
    push eax               ; push segmentsCount
    push edi               ; push pointer para o array de registros
    mov eax, [ebp+8]       ; eax = programSize
    push eax               ; push programSize

    call _f2
    add esp, 16            ; limpar 4 parâmetros (4 * 4 bytes)

    ; desalocar o array de registros.
    mov eax, [ebp-8]       ; eax = countCopy
    mov ecx, 8             ; ecx = 8
    mul ecx                ; eax = countCopy * 8
    add esp, eax           ; liberar espaço do array

    ; liberar os 8 bytes dos locais (segmentsCount e countCopy)
    add esp, 8

    pop edi                ; restaurar registradores
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ----------------------------------------------------------
; f2: imprime as informações da alocacao
; Parâmetros:
;   [ebp+8]  : programSize
;   [ebp+12] : segmentsCount
;   [ebp+16] : pointer para o array de registros
;   [ebp+20] : remaining (bytes que não foram alocados)
; ----------------------------------------------------------
_f2:                
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; imprimir "Programa de %d bytes."  
    mov eax, [ebp+8]       ; eax = programSize
    push eax               ; push programSize
    push dword fmt_prog    ; push ponteiro para a string de formato
    call _printf
    add esp, 8             ; limpar argumentos

    ; verificar se segmentsCount > 0
    mov eax, [ebp+12]      ; eax = segmentsCount
    cmp eax, 0
    jle .no_alloc_header
    push dword alloc_header ; imprimir cabeçalho "Alocacao realizada:"
    call _printf
    add esp, 4
.no_alloc_header:
    ; loop para imprimir cada segmento
    xor esi, esi           ; esi = 0 (contador de loop)
.loop_f2:
    mov eax, [ebp+12]      ; eax = segmentsCount
    cmp esi, eax
    jge .after_loop_f2     ; se esi >= segmentsCount, sair do loop

    ; preparar argumentos para printf (formato: fmt_alloc)
    ; argumentos: segmento (esi+1), block address, allocated bytes
    mov eax, esi
    add eax, 1             ; segmento = esi + 1
    push eax               ; push segmento

    ; Calcular endereço do registro: pointer + (esi * 8)
    mov ebx, [ebp+16]      ; ebx = pointer para array
    mov eax, esi
    mov edx, 8
    mul edx                ; eax = esi * 8
    add eax, ebx           ; eax = endereço do registro
    ; Ler block address
    mov edx, [eax]         ; edx = block address
    push edx               ; push block address

    ; Ler allocated bytes
    mov edx, [eax+4]       ; edx = allocated bytes
    push edx               ; push allocated bytes

    push dword fmt_alloc   ; push ponteiro para formato
    call _printf
    add esp, 16            ; limpar 4 argumentos

    add esi, 1             ; incrementar loop
    jmp .loop_f2

.after_loop_f2:
    ; Verificar o parâmetro remaining ([ebp+20])
    mov eax, [ebp+20]      ; eax = remaining
    cmp eax, 0
    jg .print_error       ; se remaining > 0, há erro
    ; Se remaining == 0, imprimir mensagem de sucesso.
    push dword fmt_success
    call _printf
    add esp, 4
    jmp .end_f2
.print_error:
    push eax              ;
    push dword fmt_error
    call _printf
    add esp, 8
.end_f2:
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
