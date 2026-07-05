; Calculator ASM - Copyright (c) 2026 Marco Trinastich
; Licensed under GNU GPL v3 - see LICENSE file for details

; ================================
; String Utilities
; ================================

[bits 64]


[section .text]



; ===========================>>
; Scan Functions
; ==========



; SkipSpaces - Advances the string cursor past blanks (spaces and tabs)
; @param r12	-> string cursor
; @param r13	-> string end pointer
; @return r12	-> first non-blank char (or end)
skipSpaces:
	cmp		r12, r13						; Stop at end of string
	jae		.end
	mov		al, byte [r12]
	cmp		al, ' '
	je		.next
	cmp		al, 0x09						; Tab
	jne		.end

.next:
	add		r12, 1
	jmp		skipSpaces

.end:
	ret


; ParseInt - Parses a signed 64-bit integer (optional +/- sign followed by digits)
; @param r12	-> string cursor
; @param r13	-> string end pointer
; @return rax	-> parsed value
; @return rcx	-> 1 = parsed / 0 = error (no digits found)
; @return r12	-> advanced past the parsed number
parseInt:
	xor		rax, rax						; Value accumulator
	xor		r9, r9							; Parsed digits counter
	xor		r10, r10						; Negative sign flag

	cmp		r12, r13						; End reached => error
	jae		.error

	mov		cl, byte [r12]					; Check for an optional sign
	cmp		cl, '+'
	je		.skipSign
	cmp		cl, '-'
	jne		.loopDigits
	mov		r10, 1							; Mark value as negative

.skipSign:
	add		r12, 1

; ParseIntLoopDigits - Accumulates decimal digits
.loopDigits:
	cmp		r12, r13						; Stop at end of string
	jae		.applySign
	mov		cl, byte [r12]
	cmp		cl, '0'							; Stop at first non-digit char
	jb		.applySign
	cmp		cl, '9'
	ja		.applySign
	sub		cl, '0'
	movzx	rcx, cl
	imul	rax, rax, 10					; value = value * 10 + digit
	add		rax, rcx
	add		r9, 1
	add		r12, 1
	jmp		.loopDigits

; ParseIntApplySign - Validates the parse and applies the sign
.applySign:
	test	r9, r9							; At least one digit is required
	jz		.error
	test	r10, r10
	jz		.ok
	neg		rax								; Apply negative sign

.ok:
	mov		rcx, 1
	ret

.error:
	xor		rcx, rcx
	ret



; ===========================>>
; Format Functions
; ==========



; IntToString - Converts a signed 64-bit integer to its decimal string representation
; @param rax	-> value to convert
; @param rdx	-> destination buffer pointer
; @return rax	-> number of bytes written
; Clobbers rcx, rdx, r8
intToString:
	push	r12								; Store preserved registers
	push	r13
	mov		r12, rdx						; r12 => destination cursor
	mov		r13, rdx						; r13 => destination start (for length)

	test	rax, rax						; Emit sign for negative values
	jns		.digits
	mov		byte [r12], '-'
	add		r12, 1
	neg		rax								; Continue with the absolute value

.digits:
	mov		rcx, 10							; Decimal divisor
	mov		r8, itoa_scratch_end			; r8 => scratch end (digits are filled backward)

; IntToStringLoopDigits - Extracts digits (least significant first)
.loopDigits:
	xor		rdx, rdx
	div		rcx								; rax => value/10, rdx => value%10
	add		dl, '0'
	sub		r8, 1
	mov		byte [r8], dl					; Store digit (reversed order)
	test	rax, rax
	jnz		.loopDigits

	mov		rdx, itoa_scratch_end

; IntToStringLoopCopy - Copies digits to destination in the right order
.loopCopy:
	cmp		r8, rdx
	jae		.done
	mov		cl, byte [r8]
	mov		byte [r12], cl
	add		r8, 1
	add		r12, 1
	jmp		.loopCopy

.done:
	mov		rax, r12
	sub		rax, r13						; rax => written length
	pop		r13								; Restore preserved registers
	pop		r12
	ret


[section .bss]
itoa_scratch		resb 24					; Reversed digits scratch area (max 20 digits for a 64-bit value)
itoa_scratch_end:
