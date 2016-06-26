define(<!FILE!>, <!<!#!> /!\ $1 /!\
<!#!> ====substr(==============================,0,len($1))====!>)dnl
FILE(<!UTILITY.M4.ASM!>)

# DATA
# ----
.data
promptPrefix:
	.asciiz "=) "

resultPrefix:
	.asciiz "=O "

debugPrefix:
	.asciiz "!! "

stackPrefix:
	.asciiz ")) "

RPNPrefix:
	.asciiz ")) "

dotChar:
	.asciiz "."
spaceChar:
	.asciiz " "
newlineChar:
	.asciiz "\n"

stackINDescription:
	.asciiz "SP-: "

stackOUTDescription:
	.asciiz "SP+: "


# PROCEDURES
# ----------
.text

# === syscall wrappers ===
# All of these stomp on $t0, and some on $t1 (and, of course, on $ra.);
# `print(String|Integer)DEBUG` expect $a3; printDescribedIntegerDEBUG expects $v0 as well.

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

# ### printStringUpTo ###
# @leaf
# @param  $a0   start-address of a string to print
# @param  $a1   address at which to *stop* printing
# @stomps $t0..$t1
printStringUpTo: # @leaf
	move $t0, $v0

	lb $t1, ($a1)
	sb $0,  ($a1)

	li $v0, 4
	syscall

	sb $t1, ($a1)

	move $v0, $t0
	jr $ra

printDot: # @leaf
	move $t0, $a0
	move $t1, $v0

	li $v0, 4
	la $a0, dotChar
	syscall

	move $v0, $t1
	move $a0, $t0
	jr $ra

printSpace: # @leaf
	move $t0, $a0
	move $t1, $v0

	li $v0, 4
	la $a0, spaceChar
	syscall

	move $v0, $t1
	move $a0, $t0
	jr $ra

printNewline: # @leaf
	move $t0, $a0
	move $t1, $v0

	li $v0, 4
	la $a0, newlineChar
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
	la $a0, newlineChar
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

	la $a0, newlineChar
	syscall

	move $v0, $t1
	move $a0, $t0
	# intentional fall-through
printStringDEBUGEnd:
	jr $ra

printIntegerDEBUG: # @leaf
	lb $t0, DEBUGenable
	beqz $t0, printIntegerDEBUGEnd

	move $t0, $a0
	move $t1, $v0

	li $v0, 4
	la $a0, debugPrefix
	syscall

	li $v0, 1
	move $a0, $a3
	syscall

	li $v0, 4
	la $a0, newlineChar
	syscall

	move $v0, $t1
	move $a0, $t0
	# intentional fall-through
printIntegerDEBUGEnd:
	jr $ra

# ### printDescribedIntegerDEBUG ###
# @leaf
# @param  $a3   integer value to print
# @param  $v0   address of a descriptive string for that integer value
# @stomps $t0..$t1
printDescribedIntegerDEBUG: # @leaf
	lb $t0, DEBUGenable
	beqz $t0, printDescribedIntegerDEBUGEnd

	move $t0, $a0
	move $t1, $v0

	li $v0, 4
	la $a0, debugPrefix
	syscall

	li $v0, 4
	move $a0, $t1
	syscall

	li $v0, 1
	move $a0, $a3
	syscall

	li $v0, 4
	la $a0, newlineChar
	syscall

	move $a0, $t0
	# intentional fall-through
printDescribedIntegerDEBUGEnd:
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


# ### stack manipulation helpers! ###
#
#                     ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#              0xFF008┃(envp)                       ┃
#                     ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
#              0xFF004┃(argv)                       ┃
#                     ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
#              0xFF000│(argc)                       │◀──── (start-$sp)
#                     ├~~~~~~~~~~~~~~~~~~~~~~~~~~~~~┤ ┐
# [ ($fp)-00 ] 0xFEFFC│0x00000 (non-existent $fp)   │◀┼─── (previous-$fp)
#                     ├─────────────────────────────┤ │
# [ ($fp)-04 ] 0xFEFF8│0xFECAFECA (another $ra)     │ │   Previous
#                     ├─────────────────────────────┤ │  stack-frame
# [ ($fp)-08 ] 0xFEFF4│...                          │ │
#                     ├─────────────────────────────┤ │
# [ ($fp)-0C ] 0xFEFF0│...                          │ │
#                     ├~~~~~~~~~~~~~~~~~~~~~~~~~~~~~┤ ┘
# [  $fp +08 ] 0xFEFEC│(2nd stack-passed arg)       │
#                     ├─────────────────────────────┤
# [  $fp +04 ] 0xFEFE8│(1nd stack-passed arg)       │◀──── (previous-$sp)
#                     ├~~~~~~~~~~~~~~~~~~~~~~~~~~~~~┤ ┓
# [  $fp -00 ] 0xFEFE4│0xFEFFC (prev. $fp)          │◀╋─── $fp: 0xFEFE4
#                     ├─────────────────────────────┤ ┃
# [  $fp -04 ] 0xFEFE0│0xDEADBEEF (prev. $ra)       │ ┃
#                     ├─────────────────────────────┤ ┃    Current
# [  $fp -08 ] 0xFEFDC│...                          │ ┃  stack-frame
#                     ├─────────────────────────────┤ ┃
# [  $fp -0C ] 0xFEFD8│...                          │ ┃
#                     ├─────────────────────────────┤ ┃
# [  $fp -10 ] 0xFEFD4│...                          │◀╋─── $sp: 0xFEFD4
#                     └~~~~~~~~~~~~~~~~~~~~~~~~~~~~~┘ ┛

# ### stackIN ###
# This handles saving the $ra and $sp, updating the $sp and $fp, and advancing the stack-pointer,
# for a calling procedure. Since this is called via `jal`, it expects the pre-existing `$ra` in
# `$t8`. (Chosen because we can't stomp on the `$a` registers at the start of a non-leaf!)
# @leaf
# @param  $t9   *total* number of stack slots to make available (including $fp and $ra!)
# @param  $t8   value to store as $ra
# @stomps $t6..$t7

stackIN:
	move $t7, $ra
	addi $t9, -1                                    # Account for the $fp slot
	mul $t9, $t9, 4
	neg $t9, $t9

	addi $sp, -4                                    # Decrement (move-forward) $sp by one slot,
	sw $fp, ($sp)                                   # insert (push) the previous base-pointer,
	move $fp, $sp                                   # and update the base-pointer.

	add $sp, $sp, $t9                               # Allocate stack space for `N` 4-byte slots,
	sw $t8, -4($fp)

	lw $t6, stackStart
	sub $t6, $sp, $t6

	la $v0, stackINDescription
	move $a3, $t6
	jal printDescribedIntegerDEBUG

	jr $t7


# ### stackOUTAndReturn ###
# This restores the stack, acting as the meat of the postlude of a non-leaf procedure.
#
# Note that this *directly* jumps to the caller's-caller; meaning that `j stackOUTAndReturn` should
# be the last instruction in a non-leaf procedure.
#
# @direct
# @param  $t9   *total* number of stack slots to pop
# @stomps $t8

stackOUTAndReturn:
	mul $t9, $t9, 4

	lw $t7, -4($fp)
	lw $fp, -0($fp)
	add $sp, $sp, $t9

	lw $t8, stackStart
	sub $t8, $sp, $t8

	la $v0, stackOUTDescription
	move $a3, $t8
	jal printDescribedIntegerDEBUG

	jr $t7


# ### dumpRPNStack ###
# @non-leaf
# @param  $s7   pointer to the top (next, empty slot) of the RPN stack
# @stomps $t0..3, $a0

 dumpRPNStack:
_dumpRPNStack__prelude:
	move $t8, $ra           # Instruct stackIN to save the $ra on the stack *and*,
	li $t9, 3               # allocate stack space for THREE 4-byte items, including:
	jal stackIN
	sw $s0, -8($fp)         # the caller's $s0

	move $s0, $s7

	la $a0, RPNPrefix
	jal printString
	# intentional fall-through

_dumpRPNStack__loop:
	la $t0, rpnStack
	beq $s0, $t0, _dumpRPNStack__postlude

	addi $s0, -4                                    # shrink RPN stack by one slot,
	lw $a0, ($s0)                                   # grab previously-top item off RPN stack,
	jal printInteger                                # print it

	jal printSpace
	j _dumpRPNStack__loop

_dumpRPNStack__postlude:
	jal printNewline

	lw $s0, -8($fp)
	li $t9, 3
	j stackOUTAndReturn


# ### compareTokens ###
# @leaf
# @param  $a0   start address of first token
# @param  $a1   start address of second token
# @return $v0   1 if strings are equal, 0 if not

compareTokens:
	# Move arguments into temporaries
	move $t0, $a0
	move $t1, $a1
	j _compareStringsLoop                   # Jump into loop

_compareTokensLoop:
	# Load characters from both strings
	lb $t2, ($t0)
	lb $t3, ($t1)

	seq $t4, $t2, 10
	seq $t5, $t2, 32
	or $t4, $t4, $t5
	seq $t5, $t2, 9
	or $t4, $t4, $t5
	seq $t5, $t2, 0
	or $t4, $t4, $t5

	seq $t5, $t3, 10
	seq $t6, $t3, 32
	or $t5, $t5, $t6
	seq $t6, $t3, 9
	or $t5, $t5, $t6
	seq $t6, $t3, 0
	or $t5, $t5, $t6

	and $t4, $t4, $t5

	bnez $t4, _compareStringsReturnTrue

	seq $t4, $t2, $t3
	addi $t3, -32
	seq $t5, $t2, $t3
	or $t4, $t4, $t5

	beqz $t4, _compareStringsReturnFalse

	# Increment pointers
	addiu $t0, 1
	addiu $t1, 1

	j _compareStringsLoop                   # Loop back

_compareTokensReturnFalse:
	li $v0, 0
	jr $ra

_compareTokensReturnTrue:
	li $v0, 1
	jr $ra


# ### consumeCharacters ###
# @leaf
# @param  $a0   pointer to start of string, possibly including whitespace
# @param  $a1   if 0, will consume only whitespace; if 1, will consume only *non-whitespace*
# @return $a0   (modified in-place) pointer to first non-matching character
# @stomps $t0..2
#---
# NOTE: Several consumers make assumptions about which $t-registers this will use; don't fuck w/ dis

consumeCharacters:
	lb $t0, ($a0)
	li $t1, 32
	li $t2, 9
	seq $t1, $t0, $t1
	seq $t2, $t0, $t2
	or $t0, $t1, $t2
	beq $a1, $t0, _consumeEnd
	addi $a0, 1
	j consumeCharacters
_consumeEnd:
	jr $ra

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
