FILE(<!MATH.M4.ASM!>)

	.data
stringificationBuffer:
	.space 1024

	.text

performAdd:
	addu $v0, $a0, $a1

	# Sign bits
	and $t0, $v0, 0x80000000
	and $t1, $a1, 0x80000000
	and $t2, $a2, 0x80000000

	seq $t1, $t1, $t2              # Both operands have same sign
	sne $t0, $t0, $t1              # Result sign is not the same as first operand's sign
	and $t0, $t0, $t1              # True if overflow

	bnez $t0, __add_overflow

	jr $ra

performSub:
	neg $a1, $a1
	j performAdd

performMul:
	mult $a0, $a1
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
	bnez $t0, __mul_overflow

	jr $ra

performDiv:
	div $v0, $a0, $a1

	jr $ra

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