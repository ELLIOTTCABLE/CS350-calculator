FILE(<!MATH.M4.ASM!>)

	.text

performAdd:
	addu $v0, $a1, $a2

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
	neg $a2, $a2
	j performAdd

performMul:
	mult $a1, $a2
	
	and $t0, $a1, 0x80000000
	and $t1, $a2, 0x80000000

	

	mflo $t0

