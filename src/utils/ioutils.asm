; Calculator ASM - Copyright (c) 2023 Marco Trinastich
; Licensed under GNU GPL v3 - see LICENSE file for details

; ================================
; IO Utilities
; ================================

[bits 64]


extern GetStdHandle		; Kernel32 function to get StdHandle
						; [rcx: DWORD nStdHandle, rax: HANDLE handle [out]]
extern ReadFile			; Kernel32 function to read UTF-8 strings
						; [rcx: HANDLE hFile, rdx: LPVOID lpBuffer [out], r8: DWORD nNumberOfBytesToRead, r9: LPDWORD lpNumberOfBytesRead]
extern WriteFile		; Kernel32 function to write UTF-8 strings 						
						; [rcx: HANDLE hFile, rdx: LPVOID lpBuffer [in], r8: DWORD nNumberOfBytesToWrite, r9: LPDWORD lpNumberOfBytesWritten]
extern WriteConsoleW	; Kernel32 function to write Unicode (UTF-16/UTF-32) strings 	
						; [rcx: HANDLE hConsoleOutput, rdx: [in] LPVOID lpUnicodeBuffer, r8: DWORD nNumberOfCharsToWrite, r9: LPDWORD lpNumberOfCharsWritten]

extern AllocConsole      ; Kernel32 function to allocate a new console for the calling process
                         ; Typically used to create a console window for applications that do not have one
                         ; No parameters, returns a BOOL indicating success (nonzero) or failure (zero)

[section .text]



; ===========================>>
; Read Functions
; ==========



; ReadString - Reads utf8 strings from StdInput
; @param r8     		-> read length (optional, 0 = autodetect from message)
; @return read_buffer	-> read char/string
readString:
	test	r8, r8							; Check if no read length has been passed => read 1 char
	jnz		.end

; ReadStringDefault - Reads a message assuming 256 chars max length (default length)
.default:
	mov			r8, default_read_size

; ReadStringEnd - Finalizes ReadString
.end:
	call	clearReadBuffer
	call	.exec

    ret

; ReadStringExec - Concrete Read from StdIn function wrapping around Kernel32 ReadFile
; @param r8     		-> read length
; @return read_buffer	-> read char/string
.exec:
    call    prepareStdInHandle				; Get StdHandle

    sub     rsp, win64_home_space			; Reserve Win64 Home Space in Stack

    mov     rcx, [rel stdin]				; rcx => Set StdIn handle
    mov		rdx, read_buffer				; rdx => Set read buffer pointer
    mov     r9,  bytes_read  				; r9  => Set read char/bytes pointer
	call    ReadFile						; Read from StdIn using ReadFile

    add     rsp, win64_home_space			; Release Win64 Home Space from Stack

	ret



; ===========================>>
; Print Functions
; ==========



; PrintUnicodeString - Prints unicode message to StdOutput
; @param rdx	-> message pointer
; @param r8		-> message length (optional, 0 = autodetect from message [\0000])
printUnicodeString:
	mov		rax, 1							; Set Unicode flag to true
	call	_printString

	ret


; PrintUtf8String - Prints standard utf8 message to StdOutput
; @param rdx	-> message pointer
; @param r8		-> message length (optional, 0 = autodetect from message [\00])
printUtf8String:
	xor		rax, rax						; Set Unicode flag to false
	call	_printString

	ret


; PrintString - Prints message to StdOutput
; @param rax	-> unicode flag (0 = UTF-8 / 1 = Unicode)
; @param rdx	-> message pointer
; @param r8		-> number of chars to write (optional, 0 = autodetect from message)
_printString:
	test	r8, r8							; Check message length => 0 = dynamic print / else = fixed print
	jz		.dynamic
	call	.exec
	jmp		.end

; PrintStringDynamic - Prints a message dynamically (unknown length)
.dynamic:
	test	rax, rax						; Check unicode flag
	jz		.dynamicUtf8					; if 0 = 1 byte chars (UTF-8) else 2 bytes/1 word chars (Unicode)
	mov		byte [rel write_char_size], 2	; Set char size to 2 bytes/1 word (Unicode)
	jmp		.dynamicPreLoop

; PrintStringDynamicUtf8 - Sets char size to 1 byte (UTF-8)
.dynamicUtf8:
	mov		byte [rel write_char_size], 1	; Set char size to 1 byte (UTF-8)

.dynamicPreLoop:
	push	r12								; Store preserved registers
	push	r13			
	mov		r12, rdx						; Backup src message address

; PrintStringDynamicLoopChars - Loop over string chars
.dynamicLoopChars:
	mov		r13, print_buffer
	call	copyChar						; Copy char to print (cause it will be cleared by writefile fn)

	cmp		byte [rel print_buffer], 0x00	; Check if \00 has been reached
	je		.dynamicLoopCharsEnd
	
	mov		rdx, print_buffer				; Set char to print
	mov		r8, 1							; Set number of chars to write to 1 char
	call	.exec
	
	jmp		.dynamicLoopChars

; PrintStringDynamicLoopChars - End loop
.dynamicLoopCharsEnd:
	pop		r13								
	pop		r12								; Restore preserved registers

; PrintStringEnd - Finalizes PrintString
.end:
    ret

; PrintStringExec - Concrete Print to StdOut function wrapping around Kernel32 WriteFile/WriteConsoleW
; @param rax	-> unicode flag (0 = UTF-8 / 1 = Unicode)
; @param rdx	-> message pointer
; @param r8		-> number of chars to write (UTF-8 = 1 byte per char / Unicode = 1 word per char)
.exec:
	push	r13								; Store preserved registry and use it since rax will be overwritten
	mov		r13, rax
    call    prepareStdOutHandle				; Get StdHandle

    sub     rsp, win64_home_space			; Reserve Win64 Home Space in Stack

    mov     rcx, [rel stdout]				; rcx => Set StdOut pointer
    mov     r9, bytes_written				; r9  => Set bytesWritten/charsWritten pointer
	test	r13, r13						; Check unicode flag
	jz		.execUtf8						; if 0 = use WriteFile (UTF-8) else WriteConsoleW (Unicode)

; PrintStringExecUnicode - Prints to StdOut Unicode strings
.execUnicode:
	call    WriteConsoleW					; Print to StdOut using WriteConsoleW
	jmp		.execEnd

; PrintStringExecUnicode - Prints to StdOut UTF-8 strings
.execUtf8:
	call    WriteFile						; Print to StdOut using WriteFile

; PrintStringExecEnd - Finalizes PrintStringConcrete
.execEnd:
	add     rsp, win64_home_space			; Release Win64 Home Space from Stack
	
	mov		rax, r13						; Restore unicode flag in rax (needed by LoopChars)
	pop		r13								; Restore preserved register

	ret



; ===========================>>
; Utils Functions
; ==========



; CopyMessage - Copy message to print_buffer
; @param r12				-> src message pointer
; @param r13				-> dst message pointer
; @param write_char_size	-> memory address containing txt format (utf8/utf16)
copyChar:
	push	r14
	push	r15
	mov		r15, 1

.copyLoop:	
	mov		r14b, byte [r12]					
	mov		byte [r13], r14b				; Store byte into dst buffer
	add		r12b, 1
	add		r13b, 1
	cmp		r15b, byte [rel write_char_size]
	je		.end 							; End if format is UTF-8 (1 byte chars) else continue
	add		r15b, 1
	jmp		.copyLoop

.end:
	pop		r15
	pop		r14
	
	ret


; ClearPrintBuffer - Fills read_buffer with 0
clearReadBuffer:
	push	r11
	push	r12
	xor		r11, r11
	mov		r12, read_buffer

.clearLoop:
	cmp		r11w, word 0x0100
	je		.end
	mov		qword [r12], 0
	add		r11, 0x08
	add		r12, 0x08
	jmp		.clearLoop

.end:
	; Clears last 2 bytes dedicated to EOL
	mov		word [r12], 0

	pop		r12
	pop		r11
	ret


; ===========================>>
; Handles Functions
; ==========



; PrepareStdInHandle - Gets Standard Input pointer (console/keyboard)
; @return stdin		-> StdIn pointer
prepareStdInHandle:
    sub     rsp, win64_home_space			; Reserve Win64 Home Space in Stack

    mov     rcx, stdin_query				; rcx => StandardInput query
    call    GetStdHandle
    mov     qword [rel stdin], rax			; Save StdIn pointer into variable

    add     rsp, win64_home_space			; Release Win64 Home Space from Stack

    ret


; PrepareStdOutHandle - Gets Standard Output pointer (console/display)
; @return stdout	-> StdOut pointer
prepareStdOutHandle:
    sub     rsp, win64_home_space			; Reserve Win64 Home Space in Stack

    mov     rcx, stdout_query				; rcx => StandardOutput query
    call    GetStdHandle
    mov     qword [rel stdout], rax			; Save StdOut pointer into variable

    add     rsp, win64_home_space			; Release Win64 Home Space from Stack

    ret


[section .rodata]
stdin_query 		equ -10					; StdIn query
stdout_query 		equ -11					; StdOut query
default_read_size 	equ 256 + 2				; 256 chars + 2 for EOL (/r/n)
win64_home_space 	equ 32+16				; Win64 Funcs Home Space: 32 empty bytes to store params + 16 bytes to align stack


[section .data]
stdin 				dq 0					; StdIn pointer         // HANDLE (qword)
stdout 				dq 0					; StdOut pointer        // HANDLE (qword)
bytes_read 			dd 0 					; Total read bytes      // LPDWORD
bytes_written 		dd 0					; Total written bytes   // LPDWORD
write_char_size 	db 0					; Write char size		// BYTE


[section .bss]
read_buffer 		resb default_read_size 	; Read buffer UTF-8		// LPVOID
print_buffer		resb default_read_size 	; Print buffer UTF-8	// LPVOID
