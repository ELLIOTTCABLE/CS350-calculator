# Lucas Myers And Elliot Cable
# Final Project.asm
	
	.data # Data portion

startMessage:
	.asciiz "Welcome to the calculator."

endMessage:
	.asciiz "Goodbye!"

unrecognizedCommandMessage:
	.asciiz "Command not recognized."

overflowMessage:
	.asciiz "Overflow occured when reading an integer; try smaller numbers."

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

	.text

## Convenient Syscall Wrappers ##
printInteger:
	li $v0, 1
	syscall
	jr $ra

printIntegerLine:
	li $v0, 1
	syscall
	li $v0, 4
	la $a0, newline
	syscall
	jr $ra

printString:
	li $v0, 4
	syscall
	jr $ra

printStringLine:
	li $v0, 4
	syscall
	la $a0, newline
	syscall
	jr $ra

getInteger:
	li $v0, 5
	syscall
	jr $ra

getString:
	li $v0, 8
	syscall
	jr $ra
## End of Convenient Syscall Wrappers ##


## Integer Parsing Routine ##
# $a0 -> Start of string to parse as integer
# $v0 -> Parsed integer, -1 if overflow
# $v1 -> Pointer to string after parsed integer, 0 if overflow
readInteger:
	move $v1, $a0 # Modify v1 return value in-place
	la $t0, readIntegerBuffer # Pointer to current read location
	addiu $t1, $t0, 10 # Pointer to one past end of buffer (end of read)
	j _readIntegerReadLoop # Jump into loop

_readIntegerReadLoop:
	lb $t2, ($v1) # Load next character from string
	addi $t2, -48 # Offset ASCII value to get numerical value
	
	# Check if it's within the range of ASCII digits
	# If not, branch to the summation step
	li $t3, -1
	sgt $t3, $t2, $t3
	li $t4, 10
	slt $t4, $t2, $t4
	and $t3, $t3, $t4
	beqz $t3, _readIntegerSum

	beq $t0, $t1, _readIntegerOverflow # Jump to overflow if we're past 10 digits

	sb $t2, ($t0) # Store numerical value in buffer
	addiu $t0, 1 # Increment buffer pointer
	addiu $v1, 1 # Increment string pointer

	j _readIntegerReadLoop # Loop back

_readIntegerSum:
	li $v0, 0 # Initialize accumulation register

	# Pointer to one before start of buffer (end of read)
	la $t1, readIntegerBuffer
	addi $t1, -1

	# Step the write head backwards, since we stop one past the buffer
	addi $t0, -1

	# Initialize registers for multiplication
	li $t2, 1
	li $t3, 10

	j _readIntegerSumLoop # Jump to summation loop

_readIntegerSumLoop:
	beq $t0, $t1, _readIntegerReturn # Branch to return when done reading

	# Load byte and multiply by current place value	
	lb $t4, ($t0)
	multu $t4, $t2
	mflo $t5
	mfhi $t6
	slt $t7, $t5, $zero
	sne $t8, $t6, $zero
	or $t7, $t7, $t8
	bnez $t7, _readIntegerOverflow # Overflow check
	
	# Accumulate into $v0
	addu $v0, $v0, $t5
	bltz $v0, _readIntegerOverflow # Overflow check
	
	mul $t2, $t2, $t3 # Increase place value
	addi $t0, -1 # Decrement read pointer
	j _readIntegerSumLoop # Loop back

_readIntegerOverflow:
	li $v0, -1
	li $v1, 0
	jr $ra

_readIntegerReturn:
	jr $ra
## End of Integer Parsing Routine ##

## String Comparison Routine ##
# $a0 -> Start address of first string
# $a1 -> Start address of second string
# $v0 -> 1 if strings are equal, 0 if not
compareStrings:
	# Move arguments into temporaries
	move $t0, $a0
	move $t1, $a1
	j _compareStringsLoop # Jump into loop

_compareStringsLoop:
	# Load characters from both strings
	lb $t2, ($t0)
	lb $t3, ($t1)

	# Return conditions
	bne $t2, $t3, _compareStringsReturnFalse
	beqz $t2, _compareStringsReturnTrue # Null-termination

	# Increment pointers
	addiu $t0, 1
	addiu $t1, 1

	j _compareStringsLoop # Loop back

_compareStringsReturnFalse:
	li $v0, 0
	jr $ra

_compareStringsReturnTrue:
	li $v0, 1
	jr $ra
## End of String Comparison Routine ##

## Main Code ##
mainLoop:
	# Read in a line of input from the user
	la $a0, lineBuffer
	la $a1, 1024
	jal getString
	
	# Check if this is a command
	lb $t0, ($a0)
	li $t1, 58 # ":" character
	beq $t0, $t1, processCommand

	# Read in an integer
	jal readInteger
	li $t0, -1
	beq $t0, $v0, errorOverflow # Message on overflow

	# Print our parsed integer (for debugging)
	move $a0, $v0
	jal printIntegerLine

	j mainLoop # Loop back

errorOverflow:
	la $a0, overflowMessage
	jal printStringLine
	j mainLoop # Back to main loop

processCommand:
	addiu $a0, 1 # Move reading pointer past colon
	
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
	jal printStringLine
	j mainLoop # Back to main loop

main:
	la $a0, startMessage
	jal printStringLine
	j mainLoop # Start main loop

exit:
	la $a0, endMessage
	jal printStringLine
	li $v0, 10
	syscall
