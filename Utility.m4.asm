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
