; Calculator ASM - Copyright (c) 2023 Marco Trinastich
; Licensed under GNU GPL v3 - see LICENSE file for details

; ===============================
; Calculator ASM app entrypoint
; ===============================

[bits 64]


%include "utils/ioutils.asm"
%include "utils/strutils.asm"
%include "core/evaluator.asm"
%include "models/messages/messages.asm"
extern ExitProcess      ; Kernel32 function to Exit Process


[section .text]
global start

; Start - App entrypoint
start:
	sub		rsp, win64_home_space			; Reserve Win64 Home Space in Stack
	call 	AllocConsole					; Allocate a console for the process
	add		rsp, win64_home_space			; Release Win64 Home Space from Stack

	call	.showWelcome	
	call	.showHelp
	call	.mainloop

	call	.exit


; Mainloop - App main loop
.mainloop:
	call	.askChoice
	call	.processChoice
	test	rax, rax						; Check quit flag
	jz		.mainloop						; Loop until quit is requested

	ret


; ProcessChoice - Interprets the read input and dispatches the matching action
; @return rax	-> 0 = continue / 1 = quit requested
.processChoice:
	mov		ecx, dword [rel bytes_read]
	test	rcx, rcx						; EOF or failed read => quit (avoids prompt spinning)
	jz		.processChoiceQuit
	sub		rcx, 2							; Effective length without trailing \r\n
	jle		.processChoiceEnd				; Empty input => just re-prompt

	cmp		rcx, 1							; Single-char commands
	jne		.processChoiceExpr
	mov		r9b, byte [rel read_buffer]
	cmp		r9b, 'q'
	je		.processChoiceQuit
	cmp		r9b, 'h'
	jne		.processChoiceExpr
	call	.showHelp
	jmp		.processChoiceEnd

; ProcessChoiceExpr - Everything else is evaluated as an arithmetic expression
.processChoiceExpr:
	mov		rdx, read_buffer
	mov		r8, rcx							; Expression length (without \r\n)
	call	evaluateExpression

.processChoiceEnd:
	xor		rax, rax						; Continue main loop
	ret

; ProcessChoiceQuit - Signals the main loop to exit
.processChoiceQuit:
	mov		rax, 1							; Quit requested
	ret


; ShowWelcome - Shows app welcome message
.showWelcome:
    mov     rdx, msgWelcome
    mov     r8, msgWelcome_len
    call    printUnicodeString				; Print welcome message (unicode)

	ret


; ShowHelp - Shows app help message
.showHelp:
    mov     rdx, msgHelp
    mov     r8, msgHelp_len
    call    printUtf8String					; Print main/help message (utf8)
	
	ret


; AskChoice - Asks for a command input
.askChoice:
    mov     rdx, msgChoice
    mov     r8, msgChoice_len
    call    printUtf8String					; Print choice selection message
	xor     r8, r8
    call    readString						; Read user input (char+\r\n)
	
	ret


; Exit - Close application
.exit:
    sub     rsp, win64_home_space			; Reserve Win64 Home Space in Stack
	xor		rcx, rcx						; Success exit status (0)
    call    ExitProcess						; End application process


[section .drectve info]
        db      '/entry:start /subsystem:console /defaultlib:kernel32.lib'
