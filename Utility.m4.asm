define(<!FILE!>, <!<!#!> /!\ $1 /!\
<!#!> ====substr(==============================,0,len($1))====!>)dnl
FILE(<!UTILITY.ASM!>)

# DATA
# ----
.data
promptPrefix:
	.asciiz "=) "

resultPrefix:
	.asciiz "=O "

debugPrefix:
	.asciiz "!! "

newline:
	.asciiz "\n"

readIntegerBuffer: # Used for parsing integers
	.space 10


# PROCEDURES
# ----------
.text

# === syscall wrappers ===
# All of these stomp on $t0, and some on $t1 (and, of course, on $ra.);
# `print(String|Integer)DEBUG` expect $a3.

printInteger: # @leaf
	move $t0, $v0
	li $v0, 1
	syscall

	move $v0, $t0
	jr $ra

printString: # @leaf
	move $t0, $v0
	li $v0, 4
	syscall

	move $v0, $t0
	jr $ra

printNewline: # @leaf
	move $t0, $a0
	move $t1, $v0

	li $v0, 4
	la $a0, newline
	syscall

	move $v0, $t1
	move $a0, $t0
	jr $ra

printResult: # @leaf
	move $t0, $a0
	move $t1, $v0

	li $v0, 4
	la $a0, resultPrefix
	syscall

	li $v0, 1
	move $a0, $t0
	syscall

	li $v0, 4
	la $a0, newline
	syscall

	move $v0, $t1
	move $a0, $t0
	jr $ra

printStringDEBUG: # @leaf
	lb $t0, DEBUGenable
	beqz $t0, printStringDEBUGEnd

	move $t0, $a0
	move $t1, $v0

	li $v0, 4
	la $a0, debugPrefix
	syscall

	move $a0, $a3
	syscall

	la $a0, newline
	syscall

	move $v0, $t1
	move $a0, $t0

	printStringDEBUGEnd:
	jr $ra

printIntegerDEBUG: # @leaf
	lb $t0, DEBUGenable
	beqz $t0, printStringDEBUGEnd

	move $t0, $a0
	move $t1, $v0

	li $v0, 4
	la $a0, debugPrefix
	syscall

  li $v0, 1
	move $a0, $a3
	syscall

  li $v0, 4
	la $a0, newline
	syscall

	move $v0, $t1
	move $a0, $t0

	printIntegerDEBUGEnd:
	jr $ra


# ### general utility leaf-procedures ###

getLine: # @leaf
	move $t0, $a0
	move $t1, $v0

	li $v0, 4 # println
	la $a0, promptPrefix
	syscall

	move $a0, $t0
	li $v0, 8 # readln
	syscall

	move $v0, $t1
	jr $ra


# ### readInteger ###
# @leaf
# @param  $a0   start of string to parse as integer
# @return $v0   parsed integer, 0 if failed to parse
#---
# FIXME: Modify $a0 in-place, like the rest of the procedures.

readInteger:
	la $t0, readIntegerBuffer               # Pointer to current read location
	addiu $t1, $t0, 10                      # Pointer to one past end of buffer (end of read)

	# Next-level hacking for negative numbers (not really)
	lb $t2, ($a0)
	li $t3, 1
	li $t4, -2
	li $t5, 45 # "-" character
	seq $t5, $t2, $t5
	add $a0, $a0, $t5
	mul $t4, $t5, $t4
	add $t9, $t3, $t4

	j _readIntegerDiscardLoop               # Jump into loop

_readIntegerDiscardLoop:
	lb $t2, ($a0)                           # Load next character from string

	# Check if not "0"
	li $t3, 48
	bne $t2, $t3, _readIntegerReadLoop

	# Increment and loop back
	addiu $a0, 1
	j _readIntegerDiscardLoop

_readIntegerReadLoop:
	lb $t2, ($a0)                           # Load next character from string
	addi $t2, -48                           # Offset ASCII value to get numerical value

	# Check if it's within the range of ASCII digits
	# If not, branch to the summation step
	li $t3, -1
	sgt $t3, $t2, $t3
	li $t4, 10
	slt $t4, $t2, $t4
	and $t3, $t3, $t4
	beqz $t3, _readIntegerSum

	beq $t0, $t1, _readIntegerOverflow      # Jump to overflow if we're past 10 digits

	sb $t2, ($t0)                           # Store numerical value in buffer
	addiu $t0, 1                            # Increment buffer pointer
	addiu $a0, 1                            # Increment string pointer

	j _readIntegerReadLoop                  # Loop back

_readIntegerSum:
	li $v0, 0                               # Initialize accumulation register

	# Pointer to one before start of buffer (end of read)
	la $t1, readIntegerBuffer
	addi $t1, -1

	# Step the write head backwards, since we stop one past the buffer
	addi $t0, -1

	# Initialize registers for multiplication
	li $t2, 1
	li $t3, 10

	j _readIntegerSumLoop                   # Jump to summation loop

_readIntegerSumLoop:
	beq $t0, $t1, _readIntegerReturn        # Branch to return when done reading

	# Load byte and multiply by current place value
	lb $t4, ($t0)
	multu $t4, $t2
	mflo $t5
	mfhi $t6
	slt $t7, $t5, $zero
	sne $t8, $t6, $zero
	or $t7, $t7, $t8
	bnez $t7, _readIntegerOverflow         # Overflow check

	# Accumulate into $v0
	addu $v0, $v0, $t5
	bltz $v0, _readIntegerOverflow         # Overflow check

	mul $t2, $t2, $t3                      # Increase place value
	addi $t0, -1                           # Decrement read pointer
	j _readIntegerSumLoop                  # Loop back

_readIntegerOverflow:
	la $a0, overflowMessage
	jal printString
	jal printNewline
	j mainLoop

_readIntegerReturn:
	mul $v0, $v0, $t9
	jr $ra


# ### checkOverflow ###
# Given two arguments and a result-value, this will print an error and jump to the given return-address
#
# @leaf
# @param  $a1   the first operand used,
# @param  $a2   the second operand,
# @param  $a3   the result to be checked
# @target $v0   the exceptional-address to jump to if overflow is detected

checkOverflow:
	# NYI


# ### compareStrings ###
# @leaf
# @param  $a0   start address of first null-terminated string
# @param  $a1   start address of second null-terminated string
# @return $v0   1 if strings are equal, 0 if not

compareStrings:
	# Move arguments into temporaries
	move $t0, $a0
	move $t1, $a1
	j _compareStringsLoop                   # Jump into loop

_compareStringsLoop:
	# Load characters from both strings
	lb $t2, ($t0)
	lb $t3, ($t1)

	# Return conditions
	bne $t2, $t3, _compareStringsReturnFalse
	beqz $t2, _compareStringsReturnTrue     # Null-termination

	# Increment pointers
	addiu $t0, 1
	addiu $t1, 1

	j _compareStringsLoop                   # Loop back

_compareStringsReturnFalse:
	li $v0, 0
	jr $ra

_compareStringsReturnTrue:
	li $v0, 1
	jr $ra


# ### consumeWhitespace ###
# @leaf
# @param  $a0   pointer to start of string, possibly including whitespace
# @return $a0   (modified in-place) pointer to first non-whitespace character

consumeWhitepsace:
	lb $t0, ($a0)
	li $t1, 32
	li $t2, 9
	seq $t1, $t0, $t1
	seq $t2, $t0, $t2
	or $t0, $t1, $t2
	beqz $t0, _consumeWhitspaceNonWhitespace
	addi $a0, 1
	j consumeWhitepsace
_consumeWhitspaceNonWhitespace:
	jr $ra

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
