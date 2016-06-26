FILE(<!MATH.M4.ASM!>)

	.data
stringificationBuffer:
	.space 1024

additionOverflowMessage:
	.asciiz "Overflow occured during addition:"

subtractionOverflowMessage:
	.asciiz "Overflow occured during subtraction:"

multiplicationOverflowMessage:
	.asciiz "Overflow occured during multiplication:"

performAdd:
	addu $v0, $a1, $a2

	# Sign bits
	and $t0, $v0, 0x80000000
	and $t1, $a1, 0x80000000
	and $t2, $a2, 0x80000000

	seq $t1, $t1, $t2              # Both operands have same sign
	sne $t0, $t0, $t1              # Result sign is not the same as first operand's sign
	and $t0, $t0, $t1              # True if overflow

	bnez $t0, _performAddOverflow

	jr $ra

_performAddOverflow:
	la $a0, additionOverflowMessage
	jal printString
	jal printNewline

	jal dumpRPNStack

	j CONTINUE

performSub:
	neg $a1, $a1
	# Sign bits
	and $t0, $v0, 0x80000000
	and $t1, $a1, 0x80000000
	and $t2, $a2, 0x80000000

	seq $t1, $t1, $t2              # Both operands have same sign
	sne $t0, $t0, $t1              # Result sign is not the same as first operand's sign
	and $t0, $t0, $t1              # True if overflow

	bnez $t0, _performSubOverflow

_performSubOverflow:
	la $a0, subtractionOverflowMessage
	jal printString
	jal printNewline

	jal dumpRPNStack

	j CONTINUE

performMul:
	mult $a1, $a2
	mflo $v0

	# Sign bits
	and $t0, $v0, 0x80000000
	and $t1, $a1, 0x80000000
	and $t2, $a2, 0x80000000

	xor $t1, $t1, $t2
	sne $t0, $t0, $t1              # Result sign is incorrect

	mfhi $t1
	sne $t1, $t1, $zero            # Result has high bits

	or $t0, $t0, $t1
	bnez $t0, _performMulOverflow

	jr $ra

_performMulOverflow:
	la $a0, multiplicationOverflowMessage
	jal printString
	jal printNewline

	jal dumpRPNStack

	j CONTINUE

performDiv:
	div $v0, $a1, $a2

	jr $ra

performDecimalPrint:
	move $v0, $a0
	move $t8, $ra

	jal printInteger
	jal printNewline

	jr $t8

performBinaryPrint:
	move $v0, $a0
	move $t8, $ra

	la $a1, stringificationBuffer
	jal stringifyBinary

	la $a0, stringificationBuffer
	jal printString
	jal printNewline

	jr $t8

performHexPrint:
	move $v0, $a0
	move $t8, $ra

	la $a1, stringificationBuffer
	jal stringifyHex

	la $a0, stringificationBuffer
	jal printString
	jal printNewline

	jr $t8

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
