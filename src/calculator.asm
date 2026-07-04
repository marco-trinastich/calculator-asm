; Calculator ASM - Copyright (c) 2023 Marco Trinastich
; Licensed under GNU GPL v3 - see LICENSE file for details

; ===============================
; Calculator ASM app entrypoint
; ===============================

[bits 64]


%include "utils/ioutils.asm"
%include "models/messages/messages.asm"
extern ExitProcess      ; Kernel32 function to Exit Process


[section .text]
global start

; Start - App entrypoint
start:    
	call 	AllocConsole

	call	.showWelcome	
	call	.showHelp
	call	.mainloop

	call	.exit


; Mainloop - App main loop
.mainloop:
	call	.askChoice
	mov		rdx, read_buffer
	xor		r8, r8
	call	printUtf8String
	jmp		.mainloop

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
