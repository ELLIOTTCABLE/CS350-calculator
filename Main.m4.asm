FILE(<!MAIN.ASM!>)

# DATA
# ----
.data
startMessage:
	.asciiz "Welcome to the calculator. Type your calculations in Reverse Polish Notation (i.e. prefix notation), with an operator followed by two integer operands. The result will appear on the next line. For instance, '+ 2 3' will evaluate to '5' on a new line. The +, -, *, and / operators are accepted."

endMessage:
	.asciiz "Goodbye!"

# FIXME: This is used in too many places. Differentiate.
overflowMessage:
	.asciiz "Overflow occured when reading an integer; try smaller numbers."

lineBuffer: # Used for storing lines read in from user input
	.space 1024


# PROCEDURES
# ----------
.text

# ### main input loop ###

main:
	la $a0, startMessage
	jal printString
	jal printNewline
	j mainLoop                              # Start main loop

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

exit:
	la $a0, endMessage
	jal printString
	jal printNewline
	li $v0, 10
	syscall

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
