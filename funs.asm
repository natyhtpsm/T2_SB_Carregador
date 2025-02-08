section .data
fmt_prog:       db "Programa de %d bytes.", 10, 0
alloc_header:   db "Alocacao realizada:", 10, 0
fmt_alloc:      db "Segmento %d - Endereco: %d, Bytes alocados: %d", 10, 0
fmt_error:      db "ERRO: O programa nao coube totalmente na memoria livre. Faltam %d bytes para completar a carga.", 10, 0
fmt_success:    db "Programa carregado com sucesso em sua totalidade.", 10, 0

section .text
global f1
global f2

extern printf

; ----------------------------------------------------------
; f1: simula o carregamento do programa nos blocos disponíveis.
; Parâmetros (cdecl):
;   [ebp+8]  : programSize (tamanho do programa, em bytes)
;   [ebp+12] : count (número de blocos)
;   [ebp+16] : addr do 1º bloco
;   [ebp+20] : size do 1º bloco
;   [ebp+24] : addr do 2º bloco (se existir)
;   [ebp+28] : size do 2º bloco (se existir)
;   ... e assim por diante ...
;
; Descrição do que f1 faz:
;   - Lê programSize e count.
;   - Cria um array na pilha para armazenar (addr, allocated) de cada bloco.
;   - Para cada bloco, se ainda houver "remaining" (bytes do programa a alocar),
;     calcula quanto daquele bloco será usado (allocated) e desconta de remaining.
;   - Ao final, chama f2(programSize, segmentsCount, arrayPtr, remaining).
; ----------------------------------------------------------
f1:
    push ebp
    mov  ebp, esp
    push ebx
    push esi
    push edi

    ; Reserva 8 bytes locais: [ebp-8] = count, [ebp-4] = segmentsCount
    sub  esp, 8

    ; [ebp+12] é o count
    mov  eax, [ebp+12]
    mov  [ebp-8], eax         ; count = parâmetro

    ; segmentsCount = 0
    mov  dword [ebp-4], 0

    ; EAX vai receber o programSize para calculos de "remaining"
    mov  eax, [ebp+8]         ; remaining = programSize

    ; Calcular tamanho do array = count * 8
    mov  ecx, [ebp-8]         ; ecx = count
    mov  ebx, 8
    mov  edx, ecx             ; (só para legibilidade)
    mov  eax, ecx             ; eax = count
    mul  ebx                  ; eax = count * 8

    ; Reserva espaço na pilha para o array
    sub  esp, eax
    mov  edi, esp             ; edi aponta para o array

    ; Restaura o valor de remaining a partir de programSize
    mov  eax, [ebp+8]

    ; ESI será o índice de blocos
    xor  esi, esi

.loop_f1:
    ; if (esi >= count) => sai
    mov  ecx, [ebp-8]
    cmp  esi, ecx
    jge  .after_loop

    ; if (remaining == 0) => sai
    cmp  eax, 0
    je   .after_loop

    ; Salvar remaining na pilha para uso após o cálculo de allocated
    push eax

    ; Lê addr e size do bloco corrente
    mov  edx, [ebp+16 + esi*8]   ; bloco.addr
    mov  ebx, [ebp+20 + esi*8]   ; bloco.size

    ; allocated = (remaining <= blockSize) ? remaining : blockSize
    cmp  eax, ebx
    jle  .use_remaining
    jmp  .store_alloc

.use_remaining:
    mov  ebx, eax   ; allocated = remaining

.store_alloc:
    ; Calcula onde gravar o registro (addr, allocated) no array
    mov  edx, [ebp-4]   ; edx = segmentsCount
    mov  eax, edx
    mov  ecx, 8
    mul  ecx            ; eax = segmentsCount * 8
    add  eax, edi       ; eax = endereço do registro no array

    ; Salva bloco.addr
    mov  edx, [ebp+16 + esi*8]
    mov  [eax], edx

    ; Salva allocated
    mov  [eax+4], ebx

    ; Recupera o remaining antigo, e subtrai allocated
    pop  ecx           ; ecx = remaining antes
    sub  ecx, ebx      ; remaining -= allocated
    mov  eax, ecx

    ; segmentsCount++
    mov  ecx, [ebp-4]
    add  ecx, 1
    mov  [ebp-4], ecx

    ; próximo bloco
    add  esi, 1
    jmp  .loop_f1

.after_loop:
    ; f2(programSize, segmentsCount, arrayPtr, remaining)
    push eax              ; remaining
    mov  eax, [ebp-4]     ; segmentsCount
    push eax
    push edi              ; ponteiro para o array
    mov  eax, [ebp+8]     ; programSize
    push eax

    call f2
    add  esp, 16          ; limpa 4 parâmetros

    ; Desalocar o array
    mov  eax, [ebp-8]     ; eax = count
    mov  ecx, 8
    mul  ecx              ; eax = count * 8
    add  esp, eax

    ; liberar os 8 bytes (count e segmentsCount)
    add  esp, 8

    pop  edi
    pop  esi
    pop  ebx
    mov  esp, ebp
    pop  ebp
    ret

; ----------------------------------------------------------
; f2: imprime as informações da alocação
; Parâmetros (cdecl):
;   [ebp+8]  : programSize
;   [ebp+12] : segmentsCount
;   [ebp+16] : ponteiro para o array de (addr, allocated)
;   [ebp+20] : remaining (se > 0 => não coube)
; ----------------------------------------------------------
f2:
    push ebp
    mov  ebp, esp
    push ebx
    push esi
    push edi

    ; printf("Programa de %d bytes.", programSize)
    mov  eax, [ebp+8]
    push eax
    push dword fmt_prog
    call printf
    add  esp, 8

    ; Se segmentsCount > 0, imprime o cabeçalho
    mov  eax, [ebp+12]
    cmp  eax, 0
    jle  .no_alloc_header

    push dword alloc_header
    call printf
    add  esp, 4

.no_alloc_header:
    xor  esi, esi       ; índice de loop

.loop_f2:
    mov  eax, [ebp+12]
    cmp  esi, eax
    jge  .after_loop_f2  ; se esi >= segmentsCount, sai

    ; Preparar argumentos:
    ;   printf("Segmento %d - Endereco: %d, Bytes alocados: %d",
    ;           (esi+1), blockAddr, allocated)
    mov  eax, esi
    add  eax, 1
    push eax

    ; endereço do registro = arrayPtr + (esi*8)
    mov  ebx, [ebp+16]
    mov  eax, esi
    mov  edx, 8
    mul  edx
    add  eax, ebx

    ; block address
    mov  edx, [eax]
    push edx
    ; allocated
    mov  edx, [eax+4]
    push edx

    push dword fmt_alloc
    call printf
    add  esp, 16

    add  esi, 1
    jmp  .loop_f2

.after_loop_f2:
    ; Verifica se sobrou remaining > 0
    mov  eax, [ebp+20]
    cmp  eax, 0
    jg   .print_error

    ; Se remaining == 0 => sucesso
    push dword fmt_success
    call printf
    add  esp, 4
    jmp  .end_f2

.print_error:
    push eax                ; quantidade que faltou
    push dword fmt_error
    call printf
    add  esp, 8

.end_f2:
    pop  edi
    pop  esi
    pop  ebx
    mov  esp, ebp
    pop  ebp
    ret
