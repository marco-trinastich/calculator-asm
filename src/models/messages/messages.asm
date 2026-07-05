; Calculator ASM - Copyright (c) 2023 Marco Trinastich
; Licensed under GNU GPL v3 - see LICENSE file for details

; ===============================
; App Messages
; ===============================

[bits 64]


%define u(x) __utf16__(x) 


[section .rodata]
msgWelcome			dw  u(`╔═════════════════════════════════════════╗\u000d\u000a`),
					dw  u(`║                                         ║\u000d\u000a`),
					dw  u(`║         CalculatorASM app 1.0.1         ║\u000d\u000a`),
					dw  u(`║         copyright © 2025 mtApps         ║\u000d\u000a`),
					dw  u(`║                                         ║\u000d\u000a`),
					dw  u(`╚═════════════════════════════════════════╝\u000d\u000a`), 
					dw  u(`\u000a\u000a`)												; \r\n
msgWelcome_len		equ ($-msgWelcome)/2												; div by 2 to find the UTF-16 string length (2 bytes per wchar_t)
msgHelp				db   "=====> Usage info <=====", 0x0d, 0x0a, 0x0d, 0x0a,
					db   "- q:		Quit the app", 0x0d, 0x0a, 0x0d, 0x0a,
					db   "- h:		Show help menu", 0x0d, 0x0a, 0x0d, 0x0a,
					db   "- {expression}:	Solve a simple expressions formed by", 0x0d, 0x0a, 0x0d, 0x0a,
					db   "		* addition: 		n1 + n2", 0x0d, 0x0a,
					db   "		* subtraction: 		n1 - n2", 0x0d, 0x0a,
					db   "		* multiplication: 	n1 * n2", 0x0d, 0x0a,
					db   "		* division: 		n1 / n2", 0x0d, 0x0a,
					db   "		* a combination of the above", 0x0d, 0x0a, 0x0d, 0x0a
msgHelp_len			equ $-msgHelp
msgChoice			db   "Please insert a command or an arithmetic expression and press enter:", 0x0d, 0x0a
msgChoice_len		equ $-msgChoice
msgErrInvalid		db   "Error: invalid command or expression", 0x0d, 0x0a
msgErrInvalid_len	equ $-msgErrInvalid
msgErrDivZero		db   "Error: division by zero", 0x0d, 0x0a
msgErrDivZero_len	equ $-msgErrDivZero
