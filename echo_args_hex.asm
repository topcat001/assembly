%include 'system.inc'

%define BUFFER_SIZE 2048

section .data
hexchr db '0123456789abcdef'

section .bss
obuff resb BUFFER_SIZE

section .text
global _start
_start:
  cld           ; DF=0 (stosb increments)
  mov rsp, rdi  ; The args stack
  pop rbx       ; rbx = argc
  pop rcx       ; skip argv[0]
  mov rsi, obuff
  xor rax, rax

argcloop:
  cmp rbx, 1    ; rbx == 1 means no args
  je doexit
  pop rcx       ; &argv[i]
  xor rbp, rbp  ; counter
  mov rdi, obuff

thisargloop:
    cmp byte [rcx], 0
    je dowrite

    ; convert byte to hex
    mov dl, [rcx]

    ; upper nibble
    mov al, dl
    shr al, 4
    mov al, [hexchr+rax]
    stosb
    inc rbp

    ; lower nibble
    mov al, dl
    and al, 0x0f
    mov al, [hexchr+rax]
    stosb
    inc rbp

    mov al, 0x20      ; space
    stosb
    inc rbp

    inc rcx
    jmp thisargloop

dowrite:
    mov al, 0x0a      ; newline
    stosb
    inc rbp
    mov rdi, stdout
;   mov rsi, obuff
    mov rdx, rbp
    sys.write

  dec rbx
  jmp argcloop

doexit:
  xor rdi, rdi
  sys.exit
