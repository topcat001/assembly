%include 'system.inc'

section .data
hello   db  'Hello!', 0x0a, 0x00
hbytes equ  $-hello

section .text
global _start
_start:
mov rdi, stdout
lea rsi, [rel hello]
mov rdx, hbytes
sys.write

xor rdi, rdi
sys.exit
