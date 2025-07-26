; Copyright 2025 Çınar Karaaslan
; Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
; THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

; I am not proud of what I've done here - this file is a mess.
; so, here is an overview of what we have:
; * a 512-byte area in the stack is used for storage
; * lines are stored in 16-bits, using the lower 10 bits
; * r15 stores previous time
; * r10 stores falling piece y
; * r9 stores falling piece x

%include "constants.asm"

loss_text: db ":(", 13, 10
loss_text_size: equ $ - loss_text

; layout of used stack memory
memsize: equ 512
tios_loc: equ memsize-36 ; size 36
backup_loc: equ memsize-72 ; size 36
readbuf: equ 0 ; size 1
timebuf: equ 1 ; size 16
playfield: equ 17 ; size 40 bytes (20 * 16 bits)
falling_n: equ 57 ; size 1
displaybuf: equ 58 ; size 240 bytes (20 * 10 cells + 20 NLCRs)

; piece shapes (bit with index 0 is top left)
shapes:
%include "shapes.asm"

; waits for rax nanoseconds
; will mess rax, rdi and rsi up
nwait:
	push rax ; tv_nsec
	push 0 ; tv_sec (since the stack is 8-byte-aligned this works)

	; system call nanosleep(rsp, NULL)
	mov rdi, rsp
	mov rsi, 0
	mov rax, sys_nanosleep
	syscall

	add rsp, 16
	; pop rax
	; pop rax
	ret

; produces a loop for iterating over the falling piece
; the first argument is the register that stores the shape of the falling piece
; the second argument should be the register to store the positioned line
; the third argument should be the register to store the line number
; rcx must be unused
%macro begin_falling_piece 3
	mov %3, r10 ; initialize line number to the current Y
.falling_piece_loop:
	; if we've consumed all blocks of the piece, we can exit the loop
	test %1, %1
	jz .falling_piece_outloop

	; get current line
	mov %2, %1
	and %2, 0b1111

	; shift current line to its position
	mov rcx, r9
	add cl, 4 ; increase shift count by 4; hack to handle negative x coordinates
	shl %2, cl ; shift to the left by this count
	shr %2, 4 ; undo the hack
	; NOTE: if the piece collides with the left wall, %2 will be incorrect
%endmacro

%macro end_falling_piece 3
	shr %1, 4 ; move processing to next line
	inc %3
	jmp .falling_piece_loop ; reloop
.falling_piece_outloop:
%endmacro

; sets rax to 1 if there is a collision, 0 otherwise
; messes up rax, rcx, r11, r13, r14
check_collision:
	; we assume rsp + 8 is the old stack

	xor rax, rax
	mov al, [rsp+8+falling_n] ; set to falling piece index for now
	mov ax, [shapes+eax*2] ; reset to falling piece shape

begin_falling_piece rax, r13, r11 ; r13 is line shape, r11 is line index

	; if we're out of lines 0-19 despite being within the shape of the piece, this is a collision
	cmp r11, 20
	jge .collision

	; check if we hit the right wall
	cmp r13, 0b1111111111
	jg .collision

	; check if we hit the left wall
	mov r14, r13 ; set r14 to r13, then undo the shifts
	shl r14, 4 ; redo the hack
	shr r14, cl ; undo the first shift (note that cl is still set to r9+4 by begin_falling_piece)

	xor r14, rax ; the lower 4 bits will be 0 iff we've not hit a wall
	test r14, 0b1111
	jnz .collision ; if not zero, this is a collision

	; check for collision with the current line
	xor rcx, rcx ; reset upper bits
	mov cx, [rsp+8+playfield+r11*2] ; get line
	test rcx, r13
	jnz .collision ; if there are matching blocks, it is a collision
end_falling_piece rax, r13, r11

.no_collision:
	xor rax, rax ; set rax to zero
	ret
.collision:
	mov rax, 1
	ret

entry:
	sub rsp, memsize ; allocate stack space

	; backup current terminal settings to rsp + backup_loc
	; system call ioctl(stdin, TCGETS, rsp+backup_loc)
	mov rax, sys_ioctl
	mov rdi, stdin
	mov rsi, TCGETS
	lea rdx, [rsp+backup_loc]
	syscall

	; copy terminal settings to rsp + 36
	lea rax, [rsp+backup_loc] ; set rax to rsp + backup_loc
	lea rbx, [rsp+tios_loc] ; set rbx to rsp + tios_loc
	mov rcx, rbx ; set rbx to rsp + tios_loc (constant)

.tset_loop:
	cmp rax, rcx
	je .tset_outloop

	mov dl, [rax]
	mov [rbx], dl
	inc rax
	inc rbx
	jmp .tset_loop
.tset_outloop:

	; enable raw mode
	; rcx contains our current termios settings

	mov eax, [rcx] ; iflag
	and eax, ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON)
	mov [rcx], eax

	mov eax, [rcx+4] ; oflag
	and eax, ~OPOST
	mov [rcx+4], eax

	mov eax, [rcx+8] ; cflag
	and eax, ~(CSIZE | PARENB)
	or eax, CS8
	mov [rcx+8], eax

	mov eax, [rcx+12] ; lflag
	and eax, ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN)
	mov [rcx+12], eax

	mov byte [rcx+17+VTIME], 0 ; c_cc[VTIME] = 0
	mov byte [rcx+17+VMIN], 0 ; c_cc[VMIN] = 0

	; apply termios
	; system call ioctl(stdin, TCSETS, rcx)
	mov rax, sys_ioctl
	mov rdi, stdin
	mov rsi, TCSETS
	mov rdx, rcx
	syscall

	; maintain r15 as the last clock value
	; system call clock_gettime(CLOCK_MONOTONIC, rsp+timebuf)
	mov rax, sys_clock_gettime
	mov rdi, CLOCK_MONOTONIC
	lea rsi, [rsp+timebuf]
	syscall
	mov r15, [rsp+timebuf] ; set r15 to timebuf.tv_sec

	; clear playfield
	mov r8, 0
.clear_field_loop:
	cmp r8, 40
	je .clear_field_outloop

	mov byte [rsp+playfield+r8], 0

	inc r8
	jmp .clear_field_loop
.clear_field_outloop:

.set_next_piece:
	; produce the new piece id, using the current time as hopefully random data
	mov rax, [rsp+timebuf+8] ; rax = timespec.tv_nsec
	xor rdx, rdx

	mov rbx, 7
	div rbx
	; rdx is the falling piece number now

	; each piece is 4 rotations
	; so the shape number is 4 times the falling piece number
	shl rdx, 2
	mov [rsp+falling_n], dl

	; x = 3, y = 0
	xor r10, r10
	mov r9, 3

	; check if the game's over
	call check_collision
	test rax, rax
	jnz .loss

.loop:
	; render initial playfield
	mov r8, 0 ; line counter
	lea r12, [rsp+displaybuf] ; pointer to the current byte to write to
.render_loop:
	cmp r8, 20
	je .render_outloop

	mov ax, [rsp+playfield+r8*2] ; the current line

	; check if the line contains the falling piece
	cmp r8, r10
	jl .line_rendering
	mov r11, r10
	add r11, 4
	cmp r8, r11
	jge .line_rendering

	; if we're here, r10 + 4 > r8 >= r10 (i.e. we have the falling piece)
	; put the falling piece to bx
	xor rbx, rbx
	mov bl, [rsp+falling_n]
	mov bx, [shapes+ebx*2]

	mov rcx, r8
	sub rcx, r10
	shl rcx, 2 ; multiply by 4 to indicate the number of shifts necessary
	shr rbx, cl ; bring the relevant part to the lower 4 bits
	and rbx, 0b1111; get the relevant part of the shape

	; shift the shape to its position
	mov rcx, r9
	add cl, 4 ; the hack we had
	shl rbx, cl ; shift
	shr rbx, 4 ; undo the hack

	; make the shape visible
	or ax, bx

.line_rendering:
	mov r11, 0 ; x coordinate counter
	; render one line
	.line_loop:
		cmp r11, 10
		je .line_outloop

		test ax, 1
		jz .line_loop_display0
	.line_loop_display1:
		mov byte [r12], "#"
		jmp .line_reloop
	.line_loop_display0:
		mov byte [r12], " "
	.line_reloop:
		inc r12
		inc r11
		shr ax, 1
		jmp .line_loop
	.line_outloop:

	mov byte [r12], 13 ; carriage return
	inc r12
	mov byte [r12], 10 ; newline
	inc r12

	inc r8
	jmp .render_loop
.render_outloop:

	; system call write(stdout, rsp+displaybuf, 240)
	mov rax, sys_write
	mov rdi, stdout
	lea rsi, [rsp+displaybuf]
	mov rdx, 240
	syscall

	; system call clock_gettime(CLOCK_MONOTONIC, rsp+timebuf)
	; we don't use CLOCK_PROCESS_CPUTIME_ID because we use nanosleep
	mov rax, sys_clock_gettime
	mov rdi, CLOCK_MONOTONIC
	lea rsi, [rsp+timebuf]
	syscall

	cmp r15, [rsp+timebuf] ; compare r15 with timespec.tv_tsec
	jne .iterate ; if there are iterations to do
	; otherwise receive input

	; system call read(stdin, rsp+readbuf, 1)
	mov rax, sys_read
	mov rdi, stdin
	lea rsi, [rsp+readbuf] ; TODO: check lea rsi, [rsp] vs mov rsi, rsp
	mov rdx, 1
	syscall

	test rax, rax
	jz .byte_zero

.byte_nonzero:
	; cl becomes the byte read
	mov cl, [rsp+readbuf]

	cmp cl, "w"
	je .key_w
	cmp cl, "a"
	je .key_a
	cmp cl, "s"
	je .key_s
	cmp cl, "d"
	je .key_d
	jmp .byte_zero

.key_w:
	; rotate the piece

	; get falling piece ids
	mov bl, [rsp+falling_n] ; current falling piece
	mov cl, bl ; to be set to the next falling piece
	mov bh, bl
	and bh, ~0b11
	inc cl
	and cl, 0b11
	or cl, bh

	; check collisions
	mov [rsp+falling_n], cl
	call check_collision
	test rax, rax
	jz .reloop ; if there're no collision, the change is allowed to persist

	; restore back
	mov [rsp+falling_n], bl
	jmp .reloop
.key_a:
	dec r9
	call check_collision
	test rax, rax
	jz .reloop ; once again, allow the change to persist

	; otherwise, revert
	inc r9
	jmp .reloop
.key_d:
	inc r9
	call check_collision
	test rax, rax
	jz .reloop ; persist

	dec r9 ; revert
	jmp .reloop


.iterate:
	inc r15
.key_s:
	inc r10
	call check_collision
	test rax, rax
	jz .reloop ; let the change persist

	; otherwise, put the falling piece into the playfield
	dec r10 ; first, get back to the valid y

	; no need to set higher bits to zero, they're already zero
	mov al, [rsp+falling_n] ; falling piece index
	mov ax, [shapes+eax*2] ; reset to falling piece

begin_falling_piece rax, r13, r11 ; r13 is line shape, r11 is line index
	mov rbx, r13
	or [rsp+playfield+r11*2], bx
end_falling_piece rax, r13, r11

	; now, clearing full lines
	mov rbx, 19 ; current line number
	mov rax, 0 ; pushdown count
.line_clear_loop:
	cmp rbx, 0
	jl .line_clear_outloop

	mov cx, [rsp+playfield+rbx*2] ; current line

	cmp cx, 0b1111111111
	jne .line_clear_pushdown

	; if the line is full, increment the pushdown dount and reloop
	inc rax
	jmp .line_clear_reloop

.line_clear_pushdown:
	lea rdx, [rsp+playfield+rbx*2] ; address of current line
	mov word [rdx], 0 ; set old place to zero
	mov [rdx+rax*2], cx ; push down to the new place (rax lines below)

.line_clear_reloop:
	dec rbx
	jmp .line_clear_loop
.line_clear_outloop:

	jmp .set_next_piece

.byte_zero:
.reloop:

	mov rax, 50000000
	call nwait
	jmp .loop

.loss:
	; system call write(stdout, loss_text, loss_text_size)
	mov rax, sys_write
	mov rdi, stdout
	mov rsi, loss_text
	mov rdx, loss_text_size
	syscall

	; restore termios state
	; system call ioctl(stdin, TCSETS, rsp+backup_loc)
	mov rax, sys_ioctl
	mov rdi, stdin
	mov rsi, TCSETS
	lea rdx, [rsp+backup_loc]
	syscall

	; system call exit(0)
	mov rax, sys_exit
	xor rdi, rdi ; exit code 0
	syscall
