# Lucas Myers June 18th, 2016
# Lab5.asm
# Some Conventions:
#		We don't modify argument registers in a leaf call.
#		We don't use a runtime stack.
	
	.data

startMessage:
	.asciiz "Welcome to the calculator. Type a calculation in infix notation (+, -, *, / are accepted, as well as grouping parantheses) and press enter to see the result. Type :q to quit the program."

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

lineBuffer:
	.space 1024

readIntegerBuffer:
	.space 10

	.text

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

# Integer parsing routine
# $a0 -> Start of string to parse as integer
# $v0 -> Parsed integer, -1 if overflow
# $v1 -> Pointer to string after parsed integer, 0 if overflow
readInteger:
	move $v1, $a0
	la $t0, readIntegerBuffer
	addiu $t1, $t0, 11
	j _readIntegerRead
_readIntegerRead:
	lb $t2, ($v1)
	addi $t2, -48
	
	li $t3, -1
	sgt $t3, $t2, $t3
	li $t4, 10
	slt $t4, $t2, $t4
	and $t3, $t3, $t4
	beqz $t3, _readIntegerSum

	sb $t2, ($t0)
	addiu $t0, 1
	addiu $v1, 1

	beq $t0, $t1, _readIntegerOverflow

	j _readIntegerRead
_readIntegerSum:
	li $v0, 0
	la $t1, readIntegerBuffer
	addi $t0, -1
	addi $t1, -1
	li $t2, 1
	li $t3, 10
	j _readIntegerSumLoop
_readIntegerSumLoop:
	beq $t0, $t1, _readIntegerReturn
	
	lb $t4, ($t0)
	mul $t5, $t4, $t2
	bltz $t5, _readIntegerOverflow
	
	addu $v0, $v0, $t5
	bltz $v0, _readIntegerOverflow 
	
	mul $t2, $t2, $t3 
	addi $t0, -1
	j _readIntegerSumLoop
_readIntegerOverflow:
	li $v0, -1
	li $v1, 0
	jr $ra
_readIntegerReturn:
	jr $ra


# String comparison routine
# $a0 -> Start address of first string
# $a1 -> Start address of second string
# $v0 -> 1 if strings are equal, 0 if not
compareStrings:
	move $t0, $a0
	move $t1, $a1
_compareStringsLoop:
	lb $t2, ($t0)
	lb $t3, ($t1)
	bne $t2, $t3, _compareStringsExitFalse
	beqz $t2, _compareStringsExitTrue
	addiu $t0, 1
	addiu $t1, 1
	j _compareStringsLoop
_compareStringsExitFalse:
	li $v0, 0
	jr $ra
_compareStringsExitTrue:
	li $v0, 1
	jr $ra

mainLoop:
	la $a0, lineBuffer
	la $a1, 1024
	jal getString
	
	lb $t0, ($a0)
	li $t1, 58
	beq $t0, $t1, processCommand

	jal readInteger
	li $t0, -1
	beq $t0, $v0, errorOverflow

	move $a0, $v0
	jal printIntegerLine

	j mainLoop

errorOverflow:
	la $a0, overflowMessage
	jal printStringLine
	j mainLoop

processCommand:
	addiu $a0, 1
	
	la $a1, quitCommandShort
	jal compareStrings
	bnez $v0, exit

	la $a1, quitCommandLong
	jal compareStrings
	bnez $v0, exit

	la $a0, unrecognizedCommandMessage
	jal printStringLine
	j mainLoop

main:
	la $a0, startMessage
	jal printStringLine
	j mainLoop

exit:
	la $a0, endMessage
	jal printStringLine
	li $v0, 10
	syscall
