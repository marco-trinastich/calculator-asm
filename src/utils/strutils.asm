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
; Fully register-transparent (rax preserved: callers may hold a value in it)
; @param r12	-> string cursor
; @param r13	-> string end pointer
; @return r12	-> first non-blank char (or end)
skipSpaces:
	push	rax								; Preserve rax (al is used as scan scratch)

.loop:
	cmp		r12, r13						; Stop at end of string
	jae		.end
	mov		al, byte [r12]
	cmp		al, ' '
	je		.next
	cmp		al, 0x09						; Tab
	jne		.end

.next:
	add		r12, 1
	jmp		.loop

.end:
	pop		rax
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


; ParseFixed - Parses an unsigned fixed-point decimal literal ("42", "3.14")
; Value is scaled by fixed_scale (1e6): max 12 integer digits, max 6 fraction
; digits (extra fraction digits are consumed and truncated)
; @param r12	-> string cursor
; @param r13	-> string end pointer
; @return rax	-> parsed value (scaled by fixed_scale)
; @return rcx	-> 1 = parsed / 0 = error / 3 = overflow
; @return r12	-> advanced past the parsed literal
parseFixed:
	xor		rax, rax						; Integer part accumulator
	xor		r9, r9							; Parsed digits counter

; ParseFixedLoopInt - Accumulates integer part digits
.loopInt:
	cmp		r12, r13						; Stop at end of string
	jae		.intDone
	mov		cl, byte [r12]
	cmp		cl, '0'							; Stop at first non-digit char
	jb		.intDone
	cmp		cl, '9'
	ja		.intDone
	sub		cl, '0'
	movzx	rcx, cl
	imul	rax, rax, 10					; value = value * 10 + digit
	add		rax, rcx
	add		r9, 1
	add		r12, 1
	jmp		.loopInt

.intDone:
	test	r9, r9							; At least one digit is required
	jz		.error
	cmp		r9, 12							; More than 12 integer digits => overflow
	ja		.overflow
	imul	rax, rax, fixed_scale			; Scale integer part (max 999999999999 * 1e6 < 2^63)

	cmp		r12, r13						; Optional fraction part
	jae		.ok
	cmp		byte [r12], '.'
	jne		.ok
	add		r12, 1

	xor		r9, r9							; Fraction digits counter
	xor		r10, r10						; Fraction accumulator

; ParseFixedLoopFrac - Accumulates fraction digits (truncates beyond 6)
.loopFrac:
	cmp		r12, r13						; Stop at end of string
	jae		.fracDone
	mov		cl, byte [r12]
	cmp		cl, '0'							; Stop at first non-digit char
	jb		.fracDone
	cmp		cl, '9'
	ja		.fracDone
	add		r12, 1
	cmp		r9, 6							; Truncate digits beyond the 6th
	jae		.loopFrac
	sub		cl, '0'
	movzx	rcx, cl
	imul	r10, r10, 10					; frac = frac * 10 + digit
	add		r10, rcx
	add		r9, 1
	jmp		.loopFrac

.fracDone:
	test	r9, r9							; At least one digit after '.' is required
	jz		.error

; ParseFixedPadFrac - Scales the fraction to 6 digits (e.g. .5 => 500000)
.padFrac:
	cmp		r9, 6
	jae		.applyFrac
	imul	r10, r10, 10
	add		r9, 1
	jmp		.padFrac

.applyFrac:
	add		rax, r10						; value += scaled fraction

.ok:
	mov		rcx, 1
	ret

.error:
	xor		rcx, rcx
	ret

.overflow:
	mov		rcx, 3
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


; FixedToString - Converts a signed fixed-point value (fixed_scale) to decimal string
; Prints the integer part, then '.' and up to 6 decimals with trailing zeros stripped
; @param rax	-> fixed-point value to convert
; @param rdx	-> destination buffer pointer
; @return rax	-> number of bytes written
; Clobbers rcx, rdx, r8 (via intToString)
fixedToString:
	push	r12								; Store preserved registers
	push	r13
	push	r14
	mov		r12, rdx						; r12 => destination cursor
	mov		r13, rdx						; r13 => destination start (for length)

	test	rax, rax						; Emit sign for negative values
	jns		.split
	mov		byte [r12], '-'
	add		r12, 1
	neg		rax								; Continue with the absolute value

.split:
	mov		rcx, fixed_scale
	xor		rdx, rdx
	div		rcx								; rax => integer part, rdx => fraction part
	mov		r14, rdx						; r14 => fraction part

	mov		rdx, r12
	call	intToString						; Write integer part digits
	add		r12, rax

	test	r14, r14						; No fraction => integer output
	jz		.done
	mov		byte [r12], '.'
	add		r12, 1
	mov		rcx, 100000						; Decimal place divisor (6 digits, zero-padded)

; FixedToStringLoopFrac - Writes the 6 fraction digits (most significant first)
.loopFrac:
	xor		rdx, rdx
	mov		rax, r14
	div		rcx								; rax => current digit, rdx => rest
	add		al, '0'
	mov		byte [r12], al
	add		r12, 1
	mov		r14, rdx
	mov		rax, rcx						; place divisor /= 10
	xor		rdx, rdx
	mov		r8, 10
	div		r8
	mov		rcx, rax
	test	rcx, rcx
	jnz		.loopFrac

; FixedToStringStrip - Strips trailing zeros (fraction is non-zero => never reaches the '.')
.strip:
	cmp		byte [r12-1], '0'
	jne		.done
	sub		r12, 1
	jmp		.strip

.done:
	mov		rax, r12
	sub		rax, r13						; rax => written length
	pop		r14								; Restore preserved registers
	pop		r13
	pop		r12
	ret


[section .rodata]
fixed_scale			equ 1000000				; Fixed-point scale: 6 decimal digits (value = real * 1e6)


[section .bss]
itoa_scratch		resb 24					; Reversed digits scratch area (max 20 digits for a 64-bit value)
itoa_scratch_end:
