%include 'system.inc'

%define BUFSIZE 2048

section .data
one     dd    1
ten     dd    10
thousand      dd    1000
tthou   dd    10000
fd.in   dd    stdin
fd.out  dd    stdout
envar   db    'PINHOLE='      ; Exactly 8 bytes, or 2 dwords long
pinhole db    '04,'           ; Bender's constant (0.04)
connors db    '037', 0x0a     ; Connor's constant (0.037)
usg     db    'Usage: pinhole [-b] [-c] [-e] [-p <value>] [-o <outfile>] [-i <infile>]', 0x0a
usglen  equ   $-usg
iemsg   db    "pinhole: Can't open input file", 0x0a
iemlen  equ   $-iemsg
oemsg   db    "pinhole: Can't create output file", 0x0a
oemlen  equ   $-oemsg
pinmsg  db    'pinhole: The PINHOLE constant must not be 0', 0x0a
pinlen  equ   $-pinmsg
toobig  db    'pinhole: The PINHOLE constant may not exceed 18 decimal places', 0x0a
biglen  equ   $-toobig
huhmsg  db    9, '???'
separ   db    9, '???'
sep2    db    9, '???'
sep3    db    9, '???'
sep4    db    9, '???', 0x0a
huhlen  equ   $-huhmsg
header  db    'focal length in millimeters, pinhole diameter in microns, '
        db    'F-number, normalized F-number, F-5.6 multiplier, stops '
        db    'from F-5.6', 0x0a
headlen equ $-header

section .bss
ibuffer resb  BUFSIZE
obuffer resb  BUFSIZE
dbuffer resb  20            ; decimal buffer

section .text
huh:
  call write
  mov edi, [fd.out]         ; only need 32 bits
  lea rsi, [rel huhmsg]     ; rip-relative addressing
  mov rdx, huhlen
  sys.write
  ret

perr:
  mov rdi, stderr
  lea rsi, [rel pinmsg]
  mov rdx, pinlen
  sys.write
  mov rdi, 4
  sys.exit

consttoobig:
  mov rdi, stderr
  lea rsi, [rel toobig]
  mov rdx, biglen
  sys.write
  mov rdi, 5
  sys.exit

ierr:
  mov rdi, stderr
  lea rsi, [rel iemsg]
  mov rdx, iemlen
  sys.write
  mov rdi, 1
  sys.exit

oerr:
  mov rdi, stderr
  lea rsi, [rel oemsg]
  mov rdx, oemlen
  sys.write
  mov rdi, 2
  sys.exit

usage:
  mov rdi, stderr
  lea rsi, [rel usg]
  mov rdx, usglen
  sys.write
  mov rdi, 3
  sys.exit

global _start
_start:
  nop           ; TODO for debugging only; remove!
  cld           ; string ops increment pointer (DF = 0)
  xor ebx, ebx  ; It's enough to zero the lower dword (smaller instruction, upper dword automatically zeroed)
  mov rsp, rdi  ; The args stack is rdi
  pop rcx       ; Discard argc
  pop rcx       ; and argv[0]

.arg:
  pop rcx       ; Next arg
  or rcx, rcx
  je near .getenv   ; No more arguments left

  ; rcx contains the pointer to an argument
  cmp byte [rcx], '-'
  jne short usage

  inc rcx
  mov ax, [rcx] ; The byte after the '-' in al, and the byte after that in ah (little endian)
  inc rcx       ; rcx now points to the byte after '-x'

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

  or ah, ah     ; see comment on line 106
  jne short .openoutput ; -ofile
  pop rcx       ; -o file, file in the next argv element
  jrcxz usage   ; -o file, but file is null

.openoutput:    ; rcx now points to the output filename
  mov rdi, rcx  ; path
  mov rsi, O_CREAT | O_TRUNC | O_WRONLY   ; flags
  mov rdx, 0644o  ; mode
  sys.open
  jc near oerr       ; BSD sets CF on error

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
  or ah, ah   ; see comment on line 106
  jne near .openinput ; -ifile
  pop rcx     ; -i file, file in next argv element
  or rcx, rcx
  je near usage ; -i file, but file is null

.openinput:       ; rcx now points to the input filename
  mov rdi, rcx    ; path
  mov rsi, O_RDONLY
  sys.open
  jc near ierr

  ; File opened successfully, save descriptor
  mov [fd.in], eax   ; We only reserved (and need) dword = 32 bits
  jmp near .arg

.p:
  cmp al, 'p'
  jne short .c
  or ah, ah
  jne .pcheck     ; -pvalue
  pop rcx         ; -p value, value in next argv element
  or rcx, rcx
  je near usage   ; -p value, but value is null
  mov ah, [rcx]   ; the first byte of value

.pcheck:
  cmp ah, '0'     ; if (ah < '0' || ah > '9') goto usage;
  jl near usage
  cmp ah, '9'
  ja near usage
  mov rbx, rcx    ; save starting address for the value string
  jmp near .arg

.c:
  cmp al, 'c'
  jne .b
  or ah, ah
  jne near usage
  mov rbx, connors
  jmp near .arg

.b:
  cmp al, 'b'
  jne short .e
  or ah, ah
  jne near usage
  mov rbx, pinhole
  jmp near .arg

.e:               ; csv output
  cmp al, 'e'
  jne near usage
  or ah, ah
  jne near usage
  mov al, ','
  mov [huhmsg], al
  mov [separ], al
  mov [sep2], al
  mov [sep3], al
  mov [sep4], al
  jmp near .arg

.getenv:
  ; If rbx = 0, we did not have a -p argument,
  ; and need to check the environment for 'PINHOLE='
  or rbx, rbx
  jne short .init
  xor ecx, ecx    ; Zero the counter for use below

.nextenv:
  pop rsi         ; Next env var
  or rsi, rsi
  je short .default     ; No env vars left; in particular no PINHOLE

  ; check if this env var starts with 'PINHOLE='
  mov rdi, envar
  mov cl, 2       ; 'PINHOLE=' is 2 dwords (32 bit) long
  rep cmpsd
  jne short .nextenv

  ; match, check if '=' is followed by a digit
  mov al, [rsi]   ; rsi points to the byte after '='
  cmp al, '0'
  jl short .default     ; if (al < '0') goto .default
  cmp al, '9'
  jbe .init             ; if (al <= '9') goto .init
  ; fall through

.default:
  ; We got here because we had no -p argument,
  ; and did not find the PINHOLE env var.
  mov rbx, pinhole
  ; fall through

.init:
  xor eax, eax          ; TODO this may need updating
  xor ecx, ecx
  xor edx, edx
  mov rdi, dbuffer + 1
  mov byte [dbuffer], '0'   ; Enforce 0.xxx for the constant
  mov rsi, rbx          ; No more syscalls before we process, can restore rsi
  xor ebx, ebx          ; This is used to track the remaining number of chars in the input buffer
  xor r12, r12          ; This is used as a backup for rsi
  xor r13, r13          ; Pointer to output buffer
  xor r14, r14          ; This is used as a bakup for rdi

.constloop:             ; Convert the pinhole constant to real
  lodsb                 ; al = *rsi++
  cmp al, '9'
  ja short .setconst
  cmp al, '0'
  je short .processconst
  jb short .setconst
  inc dl                ; Count the number of non-zero digits in input

.processconst:
  inc cl                ; Count the number of digits written to dbuffer
  cmp cl, 18            ; In x64 assembly, there is no packed BCD, so 18 is ad-hoc
  ja near consttoobig
  stosb                 ; *rdi++ = al
  jmp short .constloop

.setconst:
  or dl, dl
  je near perr

  ; Floating point code begins here :)
  cvtsi2sd xmm0, dword [tthou]
  cvtsi2sd xmm1, dword [one]
  cvtsi2sd xmm2, dword [ten]
  movsd xmm3, xmm1
  divsd xmm3, xmm2      ; xmm3 = 0.1
  cvtsi2sd xmm4, dword [thousand]
  mov r14, obuffer
  call loadfloat        ; xmm5 contains the float pinhole constant

  ; Make a 1/32 quickly and save it in xmm6
  mov rbp, 1
  shl rbp, 5
  cvtsi2sd xmm7, rbp
  movsd xmm6, xmm1
  divsd xmm6, xmm7      ; xmm6 = 1/32.0
  movsd xmm10, xmm5      ; xmm10 has the pinhole constant

  ; If we are creating a CSV file, print header
  cmp byte [separ], ','
  jne short .bigloop

  mov edi, [fd.out]
  lea rsi, [rel header]
  mov rdx, headlen
  sys.write

.bigloop:               ; Read and process input
  call getchar
  jc near done

  ; Skip to the end of the line if we get a '#'
  cmp al, '#'
  jne short .num
  call skiptoeol
  jmp short .bigloop

.num:                   ; Check for numbers
  cmp al, '0'
  jl .bigloop
  cmp al, '9'
  ja .bigloop

  ; We have a number
  xor ebp, ebp
  xor edx, edx

.number:
  cmp al, '0'
  je short .number0
  mov dl, 1

.number0:
  or dl, dl             ; Skip leading zeros
  je short .nextnumber
  push rax
  call putchar
  pop rax
  inc rbp
  cmp rbp, 19
  jae short .nextnumber
  mov [dbuffer + rbp], al

.nextnumber:
  call getchar
  jc short .work
  cmp al, '#'
  je short .ungetc
  cmp al, '0'
  jl short .work
  cmp al, '9'
  ja short .work
  jmp short .number

.ungetc:
  dec r12
  inc rbx

.work:
  or dl, dl
  je near .work0       ; Input had all zeros

  cmp rbp, 19
  jae near .toobig

  mov rcx, rbp
  call loadfloat        ; focal length in xmm5
  ; We need to scale up the value in xmm5 by rcx orders of magnitude
.scaleflen:
  mulsd xmm5, xmm2
  loop .scaleflen

  ; Calculate pinhole diameter D = C * sqrt(FL)
  sqrtsd xmm7, xmm5
  mulsd xmm7, xmm10     ; xmm7 now has the diameter in mm
  movsd xmm8, xmm7
  mulsd xmm8, xmm4      ; xmm8 has the diameter in um (micron)
  xor ebp, ebp

  ; Round off to 4 significant digits
.diameter:
  ucomisd xmm8, xmm0
  jb short .printdiameter
  mulsd xmm8, xmm3      ; Divide by 10
  inc rbp               ; Count the number of times we are dividing
  jmp short .diameter

.printdiameter:
  call printnumber      ; This prints the pinhole diameter

  ; Compute the F-number
  movsd xmm8, xmm5      ; xmm8 = FL
  divsd xmm8, xmm7      ; xmm8 = FL / D
  movsd xmm9, xmm8      ; save this for the next steps
  xor ebp, ebp

.fnumber:
  ucomisd xmm8, xmm0
  jb short .printfnumber
  mulsd xmm8, xmm3      ; Divide by 10
  inc rbp               ; and count
  jmp short .fnumber

.printfnumber:
  call printnumber

  ; Calculate normalised F number
  mulsd xmm9, xmm9
  xor edi, edi
  cvtsd2si rdi, xmm9    ; rdi has the integral part
  call base2logint
  mov rdi, 1
  mov rcx, rax
  shl rdi, cl           ; rdi now has the nearest power of 2
  cvtsi2sd xmm8, rdi    ; back to double
  sqrtsd xmm8, xmm8
  xor ebp, ebp
  call printnumber

  ; Calculate the multiplier from F-5.6
  movsd xmm8, xmm9
  mulsd xmm8, xmm6      ; F^2 / 32
  movsd xmm9, xmm8      ; Save the result

.fmul:
  ucomisd xmm8, xmm0
  jb short .printfmul
  mulsd xmm8, xmm3    ; Divide by 10
  inc rbp             ; and count
  jmp short .fmul

.printfmul:
  call printnumber    ; F multiplier

  ; Calculate F stops from 5.6
  cvtsd2si rdi, xmm9  ; Original F number, integral part
  call base2logint    ; rax has the number we need
  cvtsi2sd xmm8, rax  ; back to double
  xor ebp, ebp
  call printnumber    ; and print

  ; End of line
  mov al, 0xa
  call putchar
  jmp near .bigloop

.work0:
  mov al, '0'
  call putchar

.toobig:
  call huh
  jmp .bigloop

done:
  call write            ; Flush output buffer

  ; close files
  mov edi, [fd.in]
  sys.close

  mov edi, [fd.out]
  sys.close

  ; return success
  mov rdi, 0
  sys.exit

skiptoeol:
  ; keep reading until we encounter a cr, lf, or eof
  call getchar
  jc short done
  cmp al, 0xa
  jne short .cr
  ret

.cr:
  cmp al, 0xd
  jne short skiptoeol
  ret

getchar:
  or rbx, rbx           ; Is the input buffer empty?
  jne .fetch

  call read

.fetch:
  mov rsi, r12          ; rsi gets overwritten during calls to write, so we keep the pointer in r12
  lodsb
  mov r12, rsi          ; save rsi
  dec rbx
  clc
  ret

read:
  or r13, r13           ; If there is stuff in the output buffer, flush it
  je short .read

  call write

.read:
  mov edi, [fd.in]
  mov rsi, ibuffer
  mov r12, rsi          ; save rsi
  mov rdx, BUFSIZE
  sys.read
  mov rbx, rax          ; rbx indicates buffer is full
  or rax, rax
  je short .empty
  xor eax, eax
  ret

.empty:
  add rsp, byte 8       ; this ensures that read returns to getchar's caller, not getchar
  stc
  ret

putchar:
  mov rdi, r14          ; rdi gets overwritten during syscalls, so restore
  stosb
  mov r14, rdi          ; save rdi
  inc r13
  cmp r13, BUFSIZE
  je short write
  ret

write:
  or r13, r13           ; anything left to write?
  je short .ret
  sub r14, r13          ; r14 should now point to the start of the buffer
  mov edi, [fd.out]
  mov rsi, r14
  mov rdx, r13
  sys.write
  xor eax, eax
  xor r13, r13          ; buffer is empty now

.ret:
  ret

base2logint:            ; Compute the base 2 log of the number stored in rdi, rounded to the nearest int, return in rax
  xor eax, eax
  mov rsi, 1

.logloop:
  mov r10, rdi
  sub r10, rsi
  js short .done
  shl rsi, 1
  inc rax
  jmp short .logloop

.done:
  dec rax
  ret

loadfloat:              ; convert dbuffer to float and return the result in xmm5
  push rcx              ; save these
  push rsi
  std                   ; string ops now decrement
  xorpd xmm5, xmm5      ; zero all 128 bits of xmm5

  ; rcx contains the number of characters in dbuffer - 1 (not counting the leading 0)
  lea rsi, [dbuffer + rcx]  ; rsi now points to the last digit in dbuffer

.loop:
  ; load current digit in xmm11 (rax should be zero)
  lodsb
  sub al, 0x30          ; ascii digit to decimal 0-9
  cvtsi2sd xmm11, rax
  mulsd xmm11, xmm3      ; mutiply xmm11 by 0.1
  mulsd xmm5, xmm3      ; multiply xmm5 by 0.1
  addsd xmm5, xmm11      ; add xmm11 to xmm5
  loop .loop

  cld                   ; restore flags and registers
  pop rsi
  pop rcx
  ret

printnumber:            ; print the contents of xmm8 rounded to 4 decimal places
  push rbp
  mov al, [separ]
  call putchar

  ; Print the integral part of a number from a floating point register
  xor ebp, ebp
  cvtsd2si rbp, xmm8    ; ebp now has the integer
  mov eax, ebp
  or ebp, ebp
  jns short .convert
  push rax
  mov al, '-'           ; We have a negative number; this is an error!
  call putchar
  pop rax
  mov ebp, -1
  mul ebp               ; flip the sign of eax so the printing function works properly

.convert:               ; eax now contains the modulus of the number
  lea rdi, [rel dbuffer]  ; dbuffer will hold the digits in reverse
  xor ecx, ecx
  mov esi, eax
  mov ebp, 10
  xor edx, edx

.loop:
  div ebp               ; dividend is edx:eax, or in this case just eax
  mov r11, rax          ; save eax/10
  mul ebp               ; last decimal digit of eax is now zero
  xchg eax, esi         ; Exchange: eax has 1234, esi has 1230, for example
  sub eax, esi          ; eax has 4, for example
  add al, '0'           ; get ASCII value of this digit
  stosb                 ; store this digit, increment pointer
  inc rcx
  cmp rcx, 18           ; Max number of digits. This is arbitrary since there is no 80-bit BCD
  jae short .reversenumber
  mov rsi, r11          ; last digit is now chopped so we can loop
  mov rax, r11
  or esi, esi
  jz short .reversenumber
  jmp short .loop

.reversenumber:         ; Just need to putchar the digits in dbuffer in reverse
  lea rsi, [rel dbuffer + rcx - 1]  ; dbuffer has rcx bytes, so this points to the last byte or the first digit

.reverseloop:
  mov al, [rsi]         ; al = *rsi--
  dec rsi
  call putchar
  loop .reverseloop

  pop rbp               ; rbp contains the number of zeros we want to print
  or rbp, rbp
  je short .ret
  push rbp

.zeros:
  mov al, '0'
  call putchar
  dec rbp
  jne short .zeros
  pop rbp               ; rbp is callee-saved

.ret:
  ret
