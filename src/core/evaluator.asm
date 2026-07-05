; Calculator ASM - Copyright (c) 2026 Marco Trinastich
; Licensed under GNU GPL v3 - see LICENSE file for details

; ================================
; Expression Evaluator
; ================================

[bits 64]


[section .text]



; EvaluateExpression - Evaluates a "n1 [op n2]" expression and prints the result
; Supported: signed 64-bit integers, one operator among + - * /
; Sign vs operator is positional: +/- where an operand is expected is a sign
; Division prints up to 6 decimal digits via long-division remainder expansion
; @param rdx	-> expression string pointer
; @param r8		-> expression length
evaluateExpression:
	push	r12								; Store preserved registers
	push	r13
	push	r14
	push	r15

	mov		r12, rdx						; r12 => parse cursor
	mov		r13, rdx
	add		r13, r8							; r13 => end of expression

; EvaluateExpressionOperand1 - Parses the first operand
	call	skipSpaces
	call	parseInt
	test	rcx, rcx
	jz		.invalid
	mov		r14, rax						; r14 => first operand

	call	skipSpaces
	cmp		r12, r13						; Bare number => print it back as result
	jae		.printInt

; EvaluateExpressionOperator - Reads and validates the operator
	movzx	r15, byte [r12]					; r15 => operator char
	add		r12, 1
	cmp		r15b, '+'
	je		.operand2
	cmp		r15b, '-'
	je		.operand2
	cmp		r15b, '*'
	je		.operand2
	cmp		r15b, '/'
	jne		.invalid

; EvaluateExpressionOperand2 - Parses the second operand
.operand2:
	call	skipSpaces
	call	parseInt
	test	rcx, rcx
	jz		.invalid
	mov		r10, rax						; r10 => second operand

	call	skipSpaces
	cmp		r12, r13						; Trailing garbage => error
	jne		.invalid

; EvaluateExpressionCompute - Dispatches the operation
	cmp		r15b, '+'
	je		.opAdd
	cmp		r15b, '-'
	je		.opSub
	cmp		r15b, '*'
	je		.opMul
	jmp		.opDiv

.opAdd:
	add		r14, r10						; r14 => result
	jmp		.printInt

.opSub:
	sub		r14, r10
	jmp		.printInt

.opMul:
	imul	r14, r10
	jmp		.printInt

; EvaluateExpressionOpDiv - Signed division with decimal expansion
.opDiv:
	test	r10, r10						; Division by zero guard (idiv would fault)
	jz		.divByZero

	xor		r11, r11						; r11 => negative result flag
	mov		rax, r14
	test	rax, rax						; Work on absolute values to keep the sign
	jns		.divAbsDivisor					; even when the quotient is 0 (e.g. -1/2)
	neg		rax
	xor		r11, 1

.divAbsDivisor:
	test	r10, r10
	jns		.divExec
	neg		r10
	xor		r11, 1

.divExec:
	xor		rdx, rdx
	div		r10								; rax => quotient, rdx => remainder
	mov		r14, rax						; r14 => quotient
	mov		r15, rdx						; r15 => remainder (operator no longer needed)

	mov		r9, result_buffer				; Compose "= [-]<quotient>[.<decimals>]"
	mov		word [r9], "= "
	add		r9, 2
	test	r11, r11
	jz		.divQuotient
	mov		byte [r9], '-'
	add		r9, 1

.divQuotient:
	mov		rax, r14
	mov		rdx, r9
	call	intToString						; Write quotient digits
	add		r9, rax
	test	r15, r15						; No remainder => integer result
	jz		.printEol
	mov		byte [r9], '.'
	add		r9, 1
	mov		rcx, 6							; Up to 6 decimal digits

; EvaluateExpressionDivDecimals - Long-division decimal expansion of the remainder
.divDecimals:
	imul	r15, r15, 10
	mov		rax, r15
	xor		rdx, rdx
	div		r10								; rax => next digit, rdx => next remainder
	add		al, '0'
	mov		byte [r9], al
	add		r9, 1
	mov		r15, rdx
	test	r15, r15						; Expansion terminated => done
	jz		.printEol
	sub		rcx, 1
	jnz		.divDecimals
	jmp		.printEol

; EvaluateExpressionPrintInt - Composes "= <integer result>"
.printInt:
	mov		r9, result_buffer
	mov		word [r9], "= "
	add		r9, 2
	mov		rax, r14
	mov		rdx, r9
	call	intToString
	add		r9, rax

; EvaluateExpressionPrintEol - Terminates the result line and prints it
.printEol:
	mov		word [r9], 0x0a0d				; \r\n
	add		r9, 2
	mov		rdx, result_buffer
	mov		r8, r9
	sub		r8, rdx							; r8 => total composed length
	call	printUtf8String
	jmp		.end

.invalid:
	mov		rdx, msgErrInvalid
	mov		r8, msgErrInvalid_len
	call	printUtf8String					; Print invalid expression error
	jmp		.end

.divByZero:
	mov		rdx, msgErrDivZero
	mov		r8, msgErrDivZero_len
	call	printUtf8String					; Print division by zero error

.end:
	pop		r15								; Restore preserved registers
	pop		r14
	pop		r13
	pop		r12
	ret


[section .bss]
result_buffer		resb 64					; Composed result line ("= " + sign + 20 digits + '.' + 6 decimals + CRLF)
