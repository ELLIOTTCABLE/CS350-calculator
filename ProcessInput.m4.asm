FILE(<!PROCESSINPUT.M4.ASM!>)

# DATA
# ----
.data
unrecognizedCommandMessage:
	.asciiz "Unsupported command. Commands: q, quit"

operatorErrorMessage:
	.asciiz "Format: [+ | - | * | /] <integer> <integer>."


# PROCEDURES
# ----------
.text

# ### processCommand ###
# @leaf
# @param  $a0   pointer to start of string, possibly including whitespace

processCommand:
	addiu $a0, 1                            # Move reading pointer past colon

	li $a1, 0
	jal consumeCharacters

	# Check for first quit command
	la $a1, quitCommandShort
	jal compareStrings
	bnez $v0, EXIT

	# Check for second quit command
	la $a1, quitCommandLong
	jal compareStrings
	bnez $v0, EXIT

	# Complain on unrecognized command
	la $a0, unrecognizedCommandMessage
	jal printString
	jal printNewline
	j CONTINUE                              # Back to main loop


# ### processOperator ###
# @non-leaf
# @param  $a0   address of a string beginning with an operator
# @return $v1   result of calculation

 processOperator:
_processOperator__prelude:
	# NOTE: I'm confused about the conventions w.r.t the frame-pointer; it seems that, generally
	#       speaking, $fp should point to the *start* of the stack-frame (i.e. the value of $sp
	#       before any manipulation.) However, this required me to save the value of the
	#       caller's existing $fp somewhere temporary, so I can replace it, and that was a waste
	#       of quite a few instructions; so I opted to store that *guaranteed* word (caller's
	#       frame- pointer) *before* our frame-pointer (i.e. at `-4($fp)`). Thus, arguments
	#       passed to us on the stack begin with `-8($fp)` instead of the obvious `-4($fp)`.
	#       (This, as far as I can tell, matches the x86 calling-convention.)
	addi $sp, $sp, -16      # Allocate stack space for four 4-byte items:
	sw $fp, 12($sp)         # caller's $fp,
	move $fp, $sp
	sw $ra, -0($fp)         # caller's $ra,
	sw $s0, -4($fp)         # caller's $s0,
	sw $s1, -8($fp)         # caller's $s1.

_processOperator__body:
	lb $s0, ($a0)                           # Going to keep the operator char in $s0
	addi $a0, 1

	# FIXME: This may support the SYMBOL+(REG) syntax?
	li $t0, 42                              # ASCII bounds-checking:
	li $t1, 47                              # <-- 42[*] 43[+] 44[,] 45[-] 46[.] 47[/] -->
	slt $t2, $s0, $t0
	sgt $t3, $s0, $t1
	or $t2, $t2, $t3

	bnez $t2, _opERROR                      # ... error if either greater or less than our range

	la $t1, _operatorJumpTable
	addi $s0, -42                           # index from the ASCII byte into [*, +, _, -, _, /]
	mul $s0, $s0, 4
	add $s0, $s0, $t1                       # add that index to the address of our jump-table,

	jr $s0                                  # … jump into the computed address in our jump-table

_operatorConsumeTwoOperands:
	move $s5, $ra

	li $a1, 0
	jal consumeCharacters                   # advance $a0 forward past any whitespace,
	jal readInteger                         # advance $a0 past one integer, and store in $v0
	move $s1, $v0
	move $a3, $v0
 	jal printIntegerDEBUG

	li $a1, 0
	jal consumeCharacters                   # advance $a0 forward past any whitespace,
	jal readInteger                         # advance $a0 past one integer, and store in $v0
	move $s2, $v0
	move $a3, $v0
 	jal printIntegerDEBUG

	jr $s5

_operatorJumpTable:
	j _opMultiply   # *
	j _opPlus       # +
	j _opERROR      # ,
	j _opSubtract   # -
	j _opERROR      # .
	j _opDivide     # /

_opMultiply:
	jal _operatorConsumeTwoOperands

	mul $v1, $s1, $s2
	move $a3, $v1
	jal printIntegerDEBUG

	 	# Overflow-checking NYI
# 	move $a1, $s1
# 	move $a2, $s2
# 	move $a3, $v1
# 	la $v0, _processOperator__overflow
# 	jal checkOverflow

	move $a0, $a3
	jal printResult

	j _processOperator__postlude

_opPlus:
	jal _operatorConsumeTwoOperands

	addu $v1, $s1, $s2
	move $a3, $v1
	jal printIntegerDEBUG

	 	# Overflow-checking NYI
# 	move $a1, $s1
# 	move $a2, $s2
# 	move $a3, $v1
# 	la $v0, _processOperator__overflow
# 	jal checkOverflow

 	move $a0, $v1
 	jal printResult

	j _processOperator__postlude

_opSubtract:
	jal _operatorConsumeTwoOperands

	neg $s2, $s2
	addu $v1, $s1, $s2
	move $a3, $v1
	jal printIntegerDEBUG

	 	# Overflow-checking NYI
# 	move $a1, $s1
# 	move $a2, $s2
# 	move $a3, $v1
# 	la $v0, _processOperator__overflow
# 	jal checkOverflow

	move $a0, $a3
	jal printResult

	j _processOperator__postlude


_opDivide:
		jal _operatorConsumeTwoOperands

	div $v1, $s1, $s2
	move $a3, $v1
	jal printIntegerDEBUG

	 	# Overflow-checking NYI
# 	move $a1, $s1
# 	move $a2, $s2
# 	move $a3, $v1
# 	la $v0, _processOperator__overflow
# 	jal checkOverflow

	move $a0, $a3
	jal printResult

	j _processOperator__postlude

_opERROR:
	la $a0, operatorErrorMessage
	jal printString
	jal printNewline
	j _processOperator__postlude

_processOperator__overflow:
	la $a0, overflowMessage
	jal printString
	jal printNewline
	j _processOperator__postlude

_processOperator__postlude:
	lw $s1, -8($fp)
	lw $s0, -4($fp)
	lw $ra, -0($fp)
	lw $fp,  4($fp) # loads the old fp *based on* the current fp
	addi $sp, $sp, 16

	jr $ra

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
