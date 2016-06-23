FILE(<!MAIN.M4.ASM!>)

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

stackStart: # Stack-pointer as of the main-loop, for escape
	.space 4

lineBuffer: # Used for storing lines read in from user input
	.space 1024


# PROCEDURES
# ----------
.text

# ### main input loop ###

main:
	sw $sp, stackStart

	la $a0, startMessage
	jal printString
	jal printNewline
	# intentional fall-through

CONTINUE:
	lw $sp, stackStart

	# Read in a line of input from the user
	la $a0, lineBuffer
	la $a1, 1024
	jal getLine

	move $a3, $a0
	jal printStringDEBUG

	# Discard leading whitespace
	li $a1, 0
	jal consumeCharacters

	move $a3, $a0
	jal printStringDEBUG

	# Initialize the RPN stack
	la $s7, rpnStack
	jal processOperator

	j CONTINUE                              # Loop back

errorOverflow:
	la $a0, overflowMessage
	jal printString
	jal printNewline
	j CONTINUE                              # Back to main loop

EXIT:
	la $a0, endMessage
	jal printString
	jal printNewline
	li $v0, 10
	syscall

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
