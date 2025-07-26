; Copyright 2025 Çınar Karaaslan
; Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
; THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

; convenience constants
stdin: equ 0
stdout: equ 1
stderr: equ 2

; ioctl command identifiers (see asm/ioctls.h on your system)
TCGETS: equ 0x5401
TCSETS: equ 0x5402

; system call numbers
sys_read: equ 0
sys_write: equ 1
sys_ioctl: equ 16
sys_nanosleep: equ 35
sys_exit: equ 60
sys_clock_gettime: equ 228

; termios constants
; I found them on my system at two places:
; ; /usr/include/asm-generic/termbits-common.h,
; ; /usr/include/asm-generic/termbits.h

; iflag:
	IGNBRK: equ 0x0001
	BRKINT: equ 0x0002
	IGNPAR: equ 0x0004
	PARMRK: equ 0x0008
	INPCK: equ 0x0010
	ISTRIP: equ 0x0020
	INLCR: equ 0x0040
	IGNCR: equ 0x0080
	ICRNL: equ 0x0100
	IUCLC: equ 0x0200
	IXON: equ 0x0400
	IXANY: equ 0x0800
	IXOFF: equ 0x1000
	IMAXBEL: equ 0x2000
	IUTF8: equ 0x4000

; oflag (only some):
	OPOST: equ 0x01
	ONLCR: equ 0x04
	OCRNL: equ 0x08
	ONOCR: equ 0x10
	ONLRET: equ 0x20
	OFILL: equ 0x40
	OFDEL: equ 0x80

; cflag (only some):
	CS7: equ 0x020
	CS8: equ 0x030
	CSIZE: equ 0x030
	CREAD: equ 0x080
	PARENB: equ 0x100
	HUPCL: equ 0x400

; lflag (only some):
	ISIG: equ 0x0001
	ICANON: equ 0x0002
	ECHO: equ 0x0008
	ECHOE: equ 0x0010
	ECHONL: equ 0x0040
	ECHOCTL: equ 0x0200
	ECHOKE: equ 0x0800
	IEXTEN: equ 0x8000

; cc (only some):
	VTIME: equ 5
	VMIN: equ 6

; clockid_t constants (see bits/time.h on your system)
CLOCK_PROCESS_CPUTIME_ID: equ 2
CLOCK_MONOTONIC: equ 1
