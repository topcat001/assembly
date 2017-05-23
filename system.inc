; Define symbols for making system calls in assembly
%define stdin   0x00
%define stdout  0x01
%define stderr  0x02

; open flags (see /usr/include/fcntl.h)
%define O_RDONLY  0x00
%define O_WRONLY  0x01
%define O_RDWR    0x02
%define	O_CREAT   0x200
%define	O_TRUNC   0x400

; mmap flags (see /usr/include/sys/mman.h)
%define PROT_NONE   0x00
%define PROT_READ   0x01
%define PROT_WRITE  0x02
%define PROT_EXEC   0x04
; mmap flags: sharing types
%define MAP_SHARED  0x01
%define MAP_PRIVATE 0x02

; stat structure (for fstat; see /usr/include/sys/stat.h)
struc stat                         ; = offset
.st_dev          resd    0x01      ; = 0, 32 bit
.st_ino          resd    0x01      ; = 4
.st_mode         resw    0x01      ; = 8, 16 bit
.st_nlink        resw    0x01      ; = 10
.st_uid          resd    0x01      ; = 12
.st_gid          resd    0x01      ; = 16
.st_rdev         resd    0x01      ; = 20
.st_atime        resq    0x01      ; = 24, 64 bit (we are using LP64 model)
.st_atimensec    resq    0x01      ; = 32
.st_mtime        resq    0x01      ; = 40
.st_mtimensec    resq    0x01      ; = 48
.st_ctime        resq    0x01      ; = 56
.st_ctimensec    resq    0x01      ; = 64
.st_size         resq    0x01      ; = 72
.st_blocks       resq    0x01      ; = 80
.st_blksize      resd    0x01      ; = 88
.st_flags        resd    0x01      ; = 92
.st_gen          resd    0x01      ; = 96
.st_lspare       resd    0x01      ; = 100
.st_qspare       resq    0x02      ; = 104, padded to 16 bytes
.size:                             ; = 120, size
endstruc

%define SYS_nosys         0x0000
%define SYS_exit          0x0001
%define SYS_fork          0x0002
%define SYS_read          0x0003
%define SYS_write         0x0004
%define SYS_open          0x0005
%define SYS_close         0x0006
%define SYS_mmap          0x01dd ; 477
%define SYS_munmap        0x0049 ; 73
%define SYS_fstat         0x00bd ; 189
%define SYS_ftruncate     0x01e0 ; 480

section .text

%macro system 1
  mov rax, %1
  syscall
%endmacro

%macro sys.exit         0
  system SYS_exit
%endmacro

%macro sys.fork         0
  system SYS_fork
%endmacro

%macro sys.read         0
  system SYS_read
%endmacro

%macro sys.write        0
  system SYS_write
%endmacro

%macro sys.open        0
  system SYS_open
%endmacro

%macro sys.close        0
  system SYS_close
%endmacro

%macro sys.mmap         0
  system SYS_mmap
%endmacro

%macro sys.munmap       0
  system SYS_munmap
%endmacro

%macro sys.ftruncate    0
  system SYS_ftruncate
%endmacro

%macro sys.fstat        0
  system SYS_fstat
%endmacro
