; Calculator ASM - Copyright (c) 2026 Marco Trinastich
; Licensed under GNU GPL v3 - see LICENSE file for details

; ================================
; Expression Evaluator
; ================================
;
; Recursive descent parser over the grammar (precedence emerges from nesting):
;   expression = term   (('+'|'-') term)*
;   term       = factor (('*'|'/') factor)*
;   factor     = ('+'|'-') factor | '(' expression ')' | fixed-point literal
;
; All arithmetic is signed 64-bit fixed-point scaled by fixed_scale (1e6):
; range is about +/- 9.2 * 10^12 with 6 decimal digits.
; Multiply and divide use the full 128-bit rdx:rax intermediates of one-operand
; imul/idiv, with pre-division guards against quotient overflow (#DE fault).
;
; Parse status protocol (rcx): 1 = ok / 0 = syntax error / 2 = division by zero / 3 = overflow

[bits 64]


[section .text]



; EvaluateExpression - Parses, evaluates and prints a full expression line
; @param rdx	-> expression string pointer
; @param r8		-> expression length
evaluateExpression:
	push	r12								; Store preserved registers
	push	r13
	push	r14

	mov		r12, rdx						; r12 => parse cursor
	mov		r13, rdx
	add		r13, r8							; r13 => end of expression

	call	parseExpression
	cmp		rcx, 1
	jne		.fail
	mov		r14, rax						; r14 => result value

	call	skipSpaces
	cmp		r12, r13						; Trailing garbage (e.g. stray ')') => error
	jne		.invalid

; EvaluateExpressionPrint - Composes and prints "= <result>"
	mov		r9, result_buffer
	mov		word [r9], "= "
	add		r9, 2
	mov		rax, r14
	mov		rdx, r9
	call	fixedToString
	add		r9, rax
	mov		word [r9], 0x0a0d				; \r\n
	add		r9, 2
	mov		rdx, result_buffer
	mov		r8, r9
	sub		r8, rdx							; r8 => total composed length
	call	printUtf8String
	jmp		.end

; EvaluateExpressionFail - Dispatches the error message by parse status
.fail:
	cmp		rcx, 2
	je		.divByZero
	cmp		rcx, 3
	je		.overflow

.invalid:
	mov		rdx, msgErrInvalid
	mov		r8, msgErrInvalid_len
	call	printUtf8String					; Print invalid expression error
	jmp		.end

.divByZero:
	mov		rdx, msgErrDivZero
	mov		r8, msgErrDivZero_len
	call	printUtf8String					; Print division by zero error
	jmp		.end

.overflow:
	mov		rdx, msgErrOverflow
	mov		r8, msgErrOverflow_len
	call	printUtf8String					; Print overflow error

.end:
	pop		r14								; Restore preserved registers
	pop		r13
	pop		r12
	ret


; ParseExpression - expression = term (('+'|'-') term)*
; @param r12/r13	-> parse cursor / end pointer
; @return rax		-> expression value
; @return rcx		-> parse status
parseExpression:
	push	r14								; r14 => accumulator
	call	parseTerm
	cmp		rcx, 1
	jne		.end
	mov		r14, rax

; ParseExpressionLoop - Folds additive operators left to right
.loop:
	call	skipSpaces
	cmp		r12, r13						; End of input => done
	jae		.ok
	mov		cl, byte [r12]
	cmp		cl, '+'
	je		.add
	cmp		cl, '-'
	je		.sub
	jmp		.ok								; Not an additive operator => caller decides

.add:
	add		r12, 1
	call	parseTerm
	cmp		rcx, 1
	jne		.end
	add		r14, rax
	jo		.overflow
	jmp		.loop

.sub:
	add		r12, 1
	call	parseTerm
	cmp		rcx, 1
	jne		.end
	sub		r14, rax
	jo		.overflow
	jmp		.loop

.ok:
	mov		rax, r14
	mov		rcx, 1

.end:
	pop		r14
	ret

.overflow:
	mov		rcx, 3
	jmp		.end


; ParseTerm - term = factor (('*'|'/') factor)*
; @param r12/r13	-> parse cursor / end pointer
; @return rax		-> term value
; @return rcx		-> parse status
parseTerm:
	push	r14								; r14 => accumulator
	push	r15								; r15 => current operand
	call	parseFactor
	cmp		rcx, 1
	jne		.end
	mov		r14, rax

; ParseTermLoop - Folds multiplicative operators left to right
.loop:
	call	skipSpaces
	cmp		r12, r13						; End of input => done
	jae		.ok
	mov		cl, byte [r12]
	cmp		cl, '*'
	je		.mul
	cmp		cl, '/'
	je		.div
	jmp		.ok								; Not a multiplicative operator => caller decides

; ParseTermMul - Fixed-point multiply: acc = acc * operand / fixed_scale
.mul:
	add		r12, 1
	call	parseFactor
	cmp		rcx, 1
	jne		.end
	mov		r15, rax
	mov		rax, r14
	imul	r15								; rdx:rax => 128-bit signed product

	mov		r10, rdx						; Overflow guard: |product| must be < fixed_scale * 2^63
	test	r10, r10						; i.e. |high qword| < fixed_scale / 2
	jns		.mulGuard
	neg		r10								; Conservative magnitude of the high qword
.mulGuard:
	cmp		r10, fixed_scale / 2
	jae		.overflow

	mov		r10, fixed_scale
	idiv	r10								; rax => scaled product
	mov		r14, rax
	jmp		.loop

; ParseTermDiv - Fixed-point divide: acc = acc * fixed_scale / operand
.div:
	add		r12, 1
	call	parseFactor
	cmp		rcx, 1
	jne		.end
	test	rax, rax						; Division by zero guard (idiv would fault)
	jz		.divByZero
	mov		r15, rax						; r15 => divisor
	mov		rax, r14
	mov		r10, fixed_scale
	imul	r10								; rdx:rax => 128-bit scaled dividend

	mov		r10, rdx						; Overflow guard: |dividend| must be < |divisor| * 2^63
	test	r10, r10						; i.e. |high qword| < |divisor| / 2 (conservative:
	jns		.divGuardAbs					; rejects divisors close to the 1e-6 minimum)
	neg		r10
.divGuardAbs:
	mov		r11, r15
	test	r11, r11
	jns		.divGuard
	neg		r11
.divGuard:
	shr		r11, 1
	cmp		r10, r11
	jae		.overflow

	idiv	r15								; rax => scaled quotient
	mov		r14, rax
	jmp		.loop

.ok:
	mov		rax, r14
	mov		rcx, 1

.end:
	pop		r15
	pop		r14
	ret

.divByZero:
	mov		rcx, 2
	jmp		.end

.overflow:
	mov		rcx, 3
	jmp		.end


; ParseFactor - factor = ('+'|'-') factor | '(' expression ')' | literal
; @param r12/r13	-> parse cursor / end pointer
; @return rax		-> factor value
; @return rcx		-> parse status
parseFactor:
	call	skipSpaces
	cmp		r12, r13						; Operand expected => error if end reached
	jae		.error
	mov		cl, byte [r12]
	cmp		cl, '+'							; Positional rule: +/- where an operand is
	je		.signPlus						; expected is a sign, not an operator
	cmp		cl, '-'
	je		.signMinus
	cmp		cl, '('
	je		.paren
	call	parseFixed						; Anything else must be a numeric literal
	ret

.signPlus:
	add		r12, 1
	call	parseFactor						; Recurse: sign applies to the next factor
	ret

.signMinus:
	add		r12, 1
	call	parseFactor
	cmp		rcx, 1
	jne		.ret
	neg		rax								; Apply negative sign

.ret:
	ret

; ParseFactorParen - Parenthesized sub-expression
.paren:
	add		r12, 1
	call	parseExpression					; Recurse into the grammar top level
	cmp		rcx, 1
	jne		.ret
	call	skipSpaces
	cmp		r12, r13						; Closing parenthesis is mandatory
	jae		.error
	cmp		byte [r12], ')'
	jne		.error
	add		r12, 1
	ret

.error:
	xor		rcx, rcx
	ret


[section .bss]
result_buffer		resb 64					; Composed result line ("= " + sign + digits + '.' + decimals + CRLF)
