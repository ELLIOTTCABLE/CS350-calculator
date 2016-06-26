FILE(<!MAIN.M4.ASM!>)

# DATA
# ----
.data

additionalStartMessage:
	.asciiz "       For additional usage information, type `,help'."

# FIXME: This is used in too many places. Differentiate.
overflowMessage:
	.asciiz "Overflow occured when reading an integer; try smaller numbers."

# FIXME: Document
noInputMessage:
	.asciiz "You must enter a command of the form ... NYI"

stackSetDescription:
	.asciiz "SP=: "

.align 2
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

	jal printUsage
	jal printNewline                        # additional blank line

	la $a0, additionalStartMessage
	jal printString
	jal printNewline
	# intentional fall-through

# Global ‘drop stack and restart’
CONTINUE:
	lw $sp, stackStart

	# Read in a line of input from the user
	la $a0, lineBuffer
	la $a1, 1024
	jal getLine

	# Discard leading whitespace
	li $a1, 0
	jal consumeCharacters

	move $a3, $a0
	jal printStringDEBUG

	lb $t0, ($a0)                           # Peek the first character into $t0
	beq $t0, 10, _errorNoInput              # If line-feed, error

	# Initialize the RPN stack
	la $s7, rpnStack
	jal evaluateRPN

	j CONTINUE                              # Loop back

_errorNoInput:
	la $a0, noInputMessage
	jal printString
	jal printNewline
	j CONTINUE                              # Back to main loop

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
