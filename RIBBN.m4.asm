# Lucas Myers and ELLIOTTCABLE
# Final Project.m4.asm

# NOTES
# -----
# During text-input processing, at any given time, $a0 is treated as a global cursor into the
# last-entered text-input; and is advanced and manipulated by several procedures. (This is messy,
# and thus, $s6 is globally reserved to serve this purpose, when I have time to replace it.)
#
# Similarly, $s7 is globally reserved as the pointer into the RPN-stack; it is incremented or
# decremented as RPN operations are preformed.

changequote(<!,!>)
include(Utility.m4.asm)
include(Conversion.m4.asm)
include(Math.m4.asm)
include(Eval.m4.asm)


# DATA
# ----
.data
# Global toggle for all debugging-output; switch to `1` to enable.
DEBUGenable:
	.byte 0

additionalStartMessage:
	.asciiz "       For more comprahensive usage information, type `,help'\n       For a list of supported commands & operations, type `,commands'"

wtfMessage:
	.asciiz "Unknown error occured! D:"

endMessage:
	.asciiz "Goodbye!"

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


# Global last-ditch error handler.
WTF:
	la $a0, wtfMessage
	jal printString
	jal printNewline
	# intentional fall-through

EXIT:
	la $a0, endMessage
	jal printString
	jal printNewline
	li $v0, 10
	syscall

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
