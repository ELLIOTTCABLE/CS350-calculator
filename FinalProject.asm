# Lucas Myers And Elliot Cable
# Final Project.asm


# /!\ DATA /!\
# ============
.data

startMessage:
	.asciiz "Welcome to the calculator."

endMessage:
	.asciiz "Goodbye!"

unrecognizedCommandMessage:
	.asciiz "Unsupported command. Commands: q, quit"
	.asciiz "Command not recognized."

overflowMessage:
	.asciiz "Overflow occured when reading an integer; try smaller numbers."

operatorErrorMessage:
	.asciiz "Format: <+ | - | * | /> <number> <number>."

promptPrefix:
	.asciiz "=) "

resultPrefix:
	.asciiz "=O "

debugPrefix:
	.asciiz "!! "

newline:
	.asciiz "\n"

quitCommandShort:
	.asciiz "q\n"

quitCommandLong:
	.asciiz "quit\n"

lineBuffer: # Used for storing lines read in from user input
	.space 1024

readIntegerBuffer: # Used for parsing integers
	.space 10


# /!\ PROCEDURES /!\
# ==================
.text

# === syscall wrappers == #
# All of these stomp on $t0, and some on $t1 (and, of course, on $ra.) print(String|Integer)DEBUG expect $a3.

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
	jr $ra

printIntegerDEBUG: # @leaf
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
	jr $ra

#getInteger: # @leaf
#	move $t0, $v0
#	li $v0, 5
#	syscall
#
#	move $v0, $t0
#	jr $ra

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


# === readInteger == #
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


# === compareStrings == #
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


# === consumeWhitespace == #
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


# === processCommand == #
# @leaf
# @param  $a0   pointer to start of string, possibly including whitespace

processCommand:
	addiu $a0, 1                            # Move reading pointer past colon

	jal consumeWhitepsace

	# Check for first quit command
	la $a1, quitCommandShort
	jal compareStrings
	bnez $v0, exit

	# Check for second quit command
	la $a1, quitCommandLong
	jal compareStrings
	bnez $v0, exit

	# Complain on unrecognized command
	la $a0, unrecognizedCommandMessage
	jal printString
	jal printNewline
	j mainLoop                              # Back to main loop


# === processOperator == #
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
	move $s7, $ra

	jal consumeWhitepsace                   # advance $a0 forward past any whitespace,
	jal readInteger                         # advance $a0 past one integer, and store in $v0
	move $s1, $v0
	move $a3, $v0
 	jal printIntegerDEBUG

	jal consumeWhitepsace                   # advance $a0 forward past any whitespace,
	jal readInteger                         # advance $a0 past one integer, and store in $v0
	move $s2, $v0
	move $a3, $v0
 	jal printIntegerDEBUG

	jr $s7

_operatorJumpTable:
	j _opMultiply   # *
	j _opPlus       # +
	j _opERROR      # ,
	j _opSubtract   # -
	j _opERROR      # .
	j _opDivide     # /

_opMultiply:
	jal printString
	jal printNewline
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
	jal printString
	jal printNewline
	j _processOperator__postlude

_opDivide:
	jal printString
	jal printNewline
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


# /!\ MAIN INPUT LOOP /!\
# =======================

mainLoop:
	# Read in a line of input from the user
	la $a0, lineBuffer
	la $a1, 1024
	jal getLine

	move $a3, $a0
	jal printStringDEBUG

	# Discard leading whitespace
	jal consumeWhitepsace

	move $a3, $a0
	jal printStringDEBUG

	# Check if this is a command
	lb $t0, ($a0)
	li $t1, 58                              # ":" character
	beq $t0, $t1, processCommand

	jal processOperator

	# FIXME
	# Read in an integer
	#jal readInteger
	#li $t0, -1
	#beq $t0, $v0, errorOverflow            # Message on overflow

	j mainLoop                              # Loop back

errorOverflow:
	la $a0, overflowMessage
	jal printString
	jal printNewline
	j mainLoop                              # Back to main loop

main:
	la $a0, startMessage
	jal printString
	jal printNewline
	j mainLoop                              # Start main loop

exit:
	la $a0, endMessage
	jal printString
	jal printNewline
	li $v0, 10
	syscall


# vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
