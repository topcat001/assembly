%include 'system.inc'

%define BUFSIZE 2048

section .data
fd.in   dd    stdin
fd.out  dd    stdout
usg     db    'Usage: csv [-t<delim>] [-c<comma>] [-p] [-o <outfile>] [-i <infile>]', 0x0a
usglen  equ   $-usg
iemsg   db    "csv: Can't open input file", 0x0a
iemlen  equ   $-iemsg
oemsg   db    "csv: Can't create output file", 0x0a
oemlen  equ   $-oemsg

section .bss
ibuffer   resb    BUFSIZE
obuffer   resb    BUFSIZE

section .text

ierr:
  lea rsi, [rel iemsg]
  mov rdx, iemlen
  jmp short error   ; The short jump is a 2 byte instruction as opposed to a 3 byte near jump

oerr:
  lea rsi, [rel oemsg]
  mov rdx, oemlen
  jmp short error

usage:
  lea rsi, [rel usg]
  mov rdx, usglen
  jmp short error

error:
  mov rdi, stderr
  sys.write

  mov rdi, 1
  sys.exit

global _start
_start:
  mov rsp, rdi  ; The args stack is rdi
  pop rcx       ; Discard argc
  pop rcx       ; and argv[0]
  mov rbx, (',' << 8) | 9 ; bh = ',', bl = Tab (ascii 9)

.arg:
  pop rcx       ; Next arg
  or rcx, rcx
  je near .init      ; No more arguments left

  ; rcx contains pointer to argument
  cmp byte [rcx], '-'
  jne short usage

  inc rcx
  mov ax, [rcx] ; The byte after the '-' in al, and the byte after that in ah (little endian)

.o:
  cmp al, 'o'
  jne short .i

  ; If fd.out is not stdout, then -o has already been set!
  cmp dword [fd.out], stdout
  jne short usage

  ; Find the path to output file - it is either at [rcx+1],
  ; i.e., -ofile --
  ; or in the next argument,
  ; i.e., -o file

  inc rcx     ; points to the byte after '-o'
  or ah, ah   ; see comment on line 60
  jne short .openoutput ; -ofile
  pop rcx         ; -o file, file in next argv element
  jrcxz usage     ; -o file, but file is null

.openoutput:      ; rcx now points to the output filename
  mov rdi, rcx    ; path
  mov rsi, O_CREAT | O_TRUNC | O_WRONLY   ; flags
  mov rdx, 0644o  ; mode
  sys.open
  jc near oerr         ; BSD sets CF on error

  ; File opened successfully in mode 0644, save descriptor
  mov [fd.out], eax   ; We only reserved (and need) dword = 32 bits
  jmp short .arg

.i:
  cmp al, 'i'
  jne short .p

  ; If fd.in is not stdin, then -i has already been set!
  cmp dword [fd.in], stdin
  jne near usage

  ; Find the path to the input file
  inc rcx     ; points the byte after '-i'
  or ah, ah   ; see comment on line 60
  jne near .openinput ; -ifile
  pop rcx     ; -i file, file in next argv element
  or rcx, rcx
  je near usage ; -i file, but file is null

.openinput:       ; rcx now points to the output filename
  mov rdi, rcx    ; path
  mov rsi, O_RDONLY
  sys.open
  jc near ierr

  ; File opened successfully, save descriptor
  mov [fd.in], eax   ; We only reserved (and need) dword = 32 bits
  jmp near .arg

.p:
  cmp al, 'p'
  jne short .t
  or ah, ah
  jne near usage     ; ah must be null; -p has no value
  or ebx, 1 << 31
  jmp near .arg

.t:
  cmp al, 't'
  jne short .c
  or ah, ah         ; -t<delim>
  je near usage
  mov bl, ah
  jmp near .arg

.c:
  cmp al, 'c'
  jne near usage
  or ah, ah         ; -c<comma>
  je near usage
  mov bh, ah
  jmp near .arg

.init:
  xor eax, eax      ; return values (we save on instruction size by zeroing the lower dword; the upper dword is automatically zeroed)
  xor ebp, ebp      ; counter for input buffer
  xor r12d, r12d    ; counter for output buffer
  ;mov r13, obuffer  ; for stosb. Since rdi is used for read/write calls we need to use r13 to back this pointer
  ;mov r14, ibuffer  ; for lodsb. Since rsi is used for read/write calls we need to use r14 to back this pointer
  cld

  ; See if we are to preserve the first line
  or ebx, ebx
  js short .loop

.firstline:
  ; get rid of the first line
  call getchar
  cmp al, 0x0a
  jne short .firstline

.loop:
  ; read a byte from input
  call getchar

  ; is it a "comma" character?
  cmp al, bh
  jne short .quote

  ; replace the "comma" with a "tab"
  mov al, bl

.put:
  call putchar
  jmp short .loop

.quote:
  cmp al, '"'
  jne short .put

  ; Print everything till we get another quote or EOL.
  ; If it a quote, skip it. If is an EOL, print it
.qloop:
  call getchar
  cmp al, '"'
  je short .loop

  cmp al, 0xa
  je short .put

  call putchar
  jmp short .qloop

getchar:
  or rbp, rbp       ; input buffer has stuff in it
  jne short .fetch

  call read

.fetch:
  lodsb             ; load a byte from input buffer
  dec rbp
  ret

read:
  or r12, r12
  je short .read

  call write        ; flush output buffer before a new read

.read:
  mov edi, [fd.in]
  mov rsi, ibuffer
  mov rdx, BUFSIZE
  sys.read

  ; restore rsi, rdi
  mov rdi, obuffer  ; the output buffer is empty right after a read
  mov rsi, ibuffer

  mov rbp, rax      ; bytes read
  or rax, rax
  je short .done    ; EOF
  xor eax, eax
  ret

.done:
  ; output buffer is already flushed, close files
  mov edi, [fd.in]
  sys.close

  mov edi, [fd.out]
  sys.close

  ; return success
  mov rdi, 0
  sys.exit

putchar:
  stosb
  inc r12
  cmp r12, BUFSIZE
  je short write
  ret

write:
  or r12, r12
  je short .ret
  mov rdx, r12      ; bytes to write
  mov r12, rsi      ; save read pointer
  mov rsi, obuffer
  mov edi, [fd.out]
  sys.write

  ; restore rsi, rdi
  mov rdi, obuffer  ; output buffer is now empty
  mov rsi, r12

  xor eax, eax
  xor r12, r12    ; reset counter

.ret:
  ret
