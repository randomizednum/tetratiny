bits 64

; Tell NASM to assume that the file will be loaded at address 0x400000
; So stuff like dq somelabel will work properly
org 0x400000

; ELF header

elf_header:
	db 0x7F, "ELF" ; magic number
	db 2 ; 64 bits
	db 1 ; little endian
	db 1 ; version 1
	db 0 ; System V ABI
	db 0 ; ABI version (ignored by Linux)

	times 7 db 0 ; skip reserved bytes

	dw 2 ; e_type, executable file
	dw 0x3E ; e_machine, amd64
	dd 1 ; e_version
	dq entry ; e_entry
	dq phtable - $$ ; e_phoff
	dq 0 ; e_shoff (we don't have any section headers)
	dd 0 ; e_flags (set to 0)
	dw elf_header_size ; e_ehsize
	dw phtable_size ; e_phentsize
	dw 1 ; e_phnum, just 1 entry
	dw 0 ; e_shentsize (zero becouse we don't have SHT entries)
	dw 0 ; e_shnum (similarly)
	dw 0 ; e_shstrndx (similarly)

elf_header_size: equ $ - elf_header

; The only program header table entry

phtable:
	dd 1 ; p_type, loadable
	dd 7 ; p_flags; readable, writable and executable
	dq 0 ; p_offset (offset of this segment)
	dq $$ ; p_vaddr (virtual address of this segment)
	dq $$ ; p_paddr (physical address if needed)
	dq file_size ; p_filesz
	dq file_size ; p_memsz, memory size same as file size
	dq 1 ; p_align (Who cares about alignment? I don't.)

phtable_size: equ $ - phtable

%include "tetris.asm"

file_size: equ $ - $$
