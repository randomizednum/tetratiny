BITS 64

; Tell NASM to assume that the file will be loaded at address 0x400000
; So stuff like dq somelabel will work properly
org 0x400000

;; ELF header ;;

elf:

; magic number
db 0x7F
db 0x45
db 0x4C
db 0x46

; class set to 64 bits
db 2

; little endian
db 1

; version number 1 is used
db 1

; abi identifier (3 is Linux, 0 is sysv)
; db 3
db 0

; abi version (Linux kernel ignores this for stuff like glibc to use)
db 0

; reserved
TIMES 7 db 0

; file type (2 is executable)
dw 2

; ISA (0x3E is amd64)
dw 0x3E

; version number 1 is used
dd 1

; memory address of entry point
dq entry

; start of the program header table
dq pht - $$

; start of the section header table
dq 0 ; (nowhere)

; flags
dd 0

; size of this header
dw elfsize

; program header table entry size
dw phtsize

; number of entries in the program header table
dw 1

; section header table entry size (we don't have one)
dw 0

; number of entries in the section header table
dw 0

; index of the section header table containing section names
dw 0

elfsize: equ $ - elf

;; Program header ;;

pht:

; this is a loadable segment
dd 1

; executable and readable
dd 5

; offset, virtual address and physical address of segment
dq 0
dq $$
dq $$

; file size and memory size
dq filesize
dq filesize

; alignment
dq 1

phtsize: equ $ - pht

;; Code ;;

txt: db "Hello world!", 10
txtsize: equ $ - txt

entry:
	mov rax, 1 ; write(2)
	mov rdi, 1 ; stdout
	mov rsi, txt ; source buffer
	mov rdx, txtsize ; size
	syscall

	mov rax, 60 ; exit(2)
	mov rdi, 42 ; exit code
	syscall

;; Exit ;;

filesize: equ $ - elf
