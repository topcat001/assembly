%include 'system.inc'

section .data
usg     db    'Usage: tuc filename', 0x0a
usglen  equ   $-usg
co      db    "tuc: Can't open file.", 0x0a
colen   equ   $-co
fae     db    'tuc: File access error.', 0x0a
faelen  equ   $-fae
ftl     db    'tuc: File too long.', 0x0a
ftllen  equ   $-ftl
mae     db    'tuc: Memory allocation error.', 0x0a
maelen  equ   $-mae
trc     db    'tuc: Truncate failed.', 0x0a
trclen  equ   $-trc
mum     db    'tuc: munmap failed.', 0x0a
mumlen  equ   $-mum
clo     db    'tuc: File close failed.', 0x0a
clolen  equ   $-clo

section .bss
  tucstat: resb stat.size

section .text

memerr:
  lea rsi, [rel mae]
  mov rdx, maelen
  jmp error

toolong:
  lea rsi, [rel ftl]
  mov rdx, ftllen
  jmp error

facerr:
  lea rsi, [rel fae]
  mov rdx, faelen
  jmp error

cantopen:
  lea rsi, [rel co]
  mov rdx, colen
  jmp error

usage:
  lea rsi, [rel usg]
  mov rdx, usglen
  jmp error

trcerr:
  lea rsi, [rel trc]
  mov rdx, trclen
  jmp error

mumerr:
  lea rsi, [rel mum]
  mov rdx, mumlen
  jmp error

cloerr:
  lea rsi, [rel clo]
  mov rdx, clolen
  jmp error

error:
  mov rdi, stderr
  sys.write

  mov rdi, 1
  sys.exit

global _start
_start:
  mov rsp, rdi  ; The args stack
  pop rcx       ; argc
  pop rcx       ; argv[0]
  pop rcx       ; argv[1] or null
  jrcxz usage

  pop rax       ; Too many arguments
  or rax, rax
  jne usage

  ; Open file
  mov rdi, rcx
  mov rsi, O_RDWR
  sys.open
  jc cantopen   ; BSD sets CF on error
  mov rbp, rax  ; Save fd

  ; Find file size
  mov rdi, rbp
  mov rsi, tucstat
  sys.fstat
  jc facerr

  mov edx, [tucstat + stat.st_size + 4]
  or edx, edx
  jne toolong ; file >= 4 Gbyte
  mov rbx, [tucstat + stat.st_size]
  or ebx, ebx
  js toolong  ; file >= 2 Gbyte
  jz .quit    ; Quit if size is 0

  ; Debug: dump the bytes for st_size
  ;mov rdi, stdout
  ;lea rsi, [tucstat + stat.st_size]
  ;mov rdx, 8
  ;sys.write

  ; mmap file to memory
  ; caddr_t mmap(caddr_t addr, size_t len, int prot, int flags, int fd, off_t pos);
  mov rdi, 0
  mov rsi, rbx
  mov rdx, PROT_READ | PROT_WRITE
  mov r10, MAP_SHARED
  mov r8, rbp
  mov r9, 0
  sys.mmap
  jc memerr

  cld
  mov rdi, rax
  mov rsi, rax
  push rbx   ; Save size for munmap
  push rax   ; Save pointer for munmap
  mov rcx, rbx
  ; Initialise state machine
  mov rbx, ordinary
  mov ah, 0x0a
  xor r9, r9

.loop:
  lodsb
  call rbx
  loop .loop

  cmp rbx, ordinary
  je .filesize

  ; Else output a lf
  mov al, ah
  stosb
  inc r9

.filesize:   ; Truncate file to new size
  mov rdi, rbp
  mov rsi, r9
  sys.ftruncate
  jc trcerr

  mov rdi, rbp
  sys.close
  jc cloerr

  pop rdi
  pop rsi
  sys.munmap
  jc mumerr

.quit:
  mov rdi, 0
  sys.exit

ordinary:
  cmp al, 0x0d  ; CR
  je .cr

  cmp al, ah
  je .lf

  stosb
  inc r9
  ret

.cr:
  mov rbx, cr
  ret

.lf:
  mov rbx, lf
  ret

cr:
  cmp al, 0x0d
  je .cr

  cmp al, ah
  je .lf

  xchg al, ah
  stosb
  inc r9

  xchg al, ah
  ; fall through

.lf:
  stosb
  inc r9
  mov rbx, ordinary
  ret

.cr:
  mov al, ah
  stosb
  inc r9
  ret

lf:
  cmp al, 0x0d
  je .cr

  cmp al, ah
  je .lf

  xchg al, ah
  stosb
  inc r9

  xchg al, ah
  stosb
  inc r9
  mov rbx, ordinary
  ret

.cr:
  mov rbx, ordinary
  mov al, ah
  ; fall through

.lf:
  stosb
  inc r9
  ret
