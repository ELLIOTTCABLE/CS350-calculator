FILE(<!EVAL.M4.ASM!>)

# DATA
# ----
.data

quitCommandShort:
	.asciiz "q\n"

quitCommandFull:
	.asciiz "quit\n"

helpCommandShort:
	.asciiz "h\n"

helpCommandFull:
	.asciiz "help\n"

helpCommandWTF:
	.asciiz "wtf\n"

binOperatorShort:
	.asciiz "bin"

binOperatorFull:
	.asciiz "binary"

decOperatorShort:
	.asciiz "dec"

decOperatorFull:
	.asciiz "decimal"

peekOperatorFull:
	.asciiz "peek"

hexOperatorShort:
	.asciiz "hex"

bracketsMessage:
	.asciiz "This is a ‘Reverse Polish Notation’, or RPN, calculator; brackets are unsupported: "

tooFewOperandsMessage:
	.asciiz "Operation dispatched with too few operands on stack: "

tooFewOperationsMessage:
	.asciiz "Input exhausted without exhausting RPN stack; too many operands:"

unsupportedOperationMessage:
	.asciiz "Unsupported operation: "

unsupportedInputMessage:
	.asciiz "FATAL: Your input included unsupported characters!"

suspectedInfix:
	.asciiz "(NOTE: Your input appears to be in infix form, `foo + bar`; whereas this is an\n       RPN calculator, and expects input of the form `foo bar +`!)"

.align 2
rpnStack: # Storage for up to 64 stack-operations
	.space 256 # 4 * 64

evaluateRPNLoopDescription:
	.asciiz "RPN: looping"
dispatchTokenDescription:
	.asciiz "RPN: dispatching "
dispatchBinaryDescription:
	.asciiz "RPN: dispatching binary"
dispatchUnaryDescription:
	.asciiz "RPN: dispatching unary"
pushIntegerDescription:
	.asciiz "RPN: Pushing "

# PROCEDURES
# ----------
.text

# ### extractTokenBounds ###
# This will extract the bounds of a single ‘token’ (bounded by whitespace), starting after the
# passed cursor-pointer.
#
# @leaf
# @param  $a0   cursor into a string at which to begin parsing tokens
# @return $v0   cursor into the same string, at the first character of the first token
# @return $v1   cursor into the same string, at the last character of the first token
# @stomps $t0..5

extractTokenBounds:
	move $t3, $ra
	move $t4, $a0
	move $t5, $a1

	# Consume whitespace,
	li $a1, 0
	jal consumeCharacters
	move $v0, $a0

	# then consume non-whitespace
	li $a1, 1
	jal consumeCharacters
	addi $a0, -1                            # Decrement the read-cursor by one
	move $v1, $a0

	move $a1, $t5                           # Restore $a1
	move $a0, $t4                           # Restore the read-cursor
	jr $t3


# ### evaluateRPN ###

 evaluateRPN:
_evaluateRPN__prelude:
	move $t8, $ra           # Instruct stackIN to save the $ra on the stack *and*,
	li $t9, 3               # allocate stack space for THREE 4-byte items, including:
	jal stackIN
	sw $s0, -8($fp)         # the caller's $s0

	li $v1, 0
	# intentional fall-through

_evaluateRPN__loop:
	la $a3, evaluateRPNLoopDescription
	jal printStringDEBUG
	move $a3, $a0
	jal printStringDEBUG

	# Consume whitespace
	li $a1, 0
	jal consumeCharacters

	jal dispatchToken

	lb $t0, ($a0)                           # Peek the first character into $t0
	bne $t0, 10, _evaluateRPN__loop         # If line-feed, we're done
	# intentional fall-through

_evaluateRPN__verify:
	# If the stack hasn't been exhausted, it's an error
	la $t0, rpnStack
	addi $t0, 4
	bne $t0, $s7, _evaluateRPN__incomplete

	jal dumpRPNStack                                # We dump the stack, which we've just
	j _evaluateRPN__postlude                        # verified has one item, as result ‘output’

_evaluateRPN__incomplete:
	la $a0, tooFewOperationsMessage
	jal printString
	jal printNewline

	jal dumpRPNStack
	# intentional fall-through

_evaluateRPN__postlude:
	lw $s0, -8($fp)
	li $t9, 3
	j stackOUTAndReturn


# ### dispatchToken ###
# @non-leaf
# @param  $a0   address of the first character (non-whitespace) of a token
# @param  $a1   address of the  character (non-whitespace) of a token
# @return $a0   (MODIFIED) address of the first character (whitespace) *after* the token

 dispatchToken:
_dispatchToken__prelude:
	move $t8, $ra           # Instruct stackIN to save the $ra on the stack *and*,
	li $t9, 4               # allocate stack space for THREE 4-byte items, including:
	jal stackIN
	sw $s0,  -8($fp)
	sw $s1, -12($fp)
	# intentional fall-through

_dispatchToken__body:
	lb $s0, ($a0)                           # Peek the first character into $s0

	la $v0, dispatchTokenDescription
	move $a3, $s0
	jal printDescribedIntegerDEBUG

	# ASCII bounds-checking:
	# <~~~                                  # Out-of-bounds control-characters:     erraneous
	# 33[!]..39[']                          # Unsupported / non-implemented ops:    erraneous
	# 40[(] 41[)]                           # RPN error; no grouping:               erraneous
	# 42[*] 43[+] 44[,] 45[-] 46[.] 47[/]   # Primary ops:                          direct
	# 48[0]                                 # 0-prefix, possible base-change:       peek, push
	# 49[1]..57[9]                          # Digit, start of a base-10 integer:    direct, push
	# 58[;]..64[@]                          # Unsupported / non-implemented ops:    erraneous
	# 65[A]..90[Z]                          # Long-form ops:                        dispatch
	# 91[[]..96[`]                          # Unsupported / non-implemented ops:    erraneous
	# 97[a]..122[z]                         # Long-form ops:                        dispatch
	# ~~~>                                  # Unsupported / non-implemented ops:    erraneous
	#
	# Only a few of these are ambiguous beyond the first character read, and require special
	# handling:
	#
	#  - PLUS `+` and HYPHEN `-` can be both standalone, binary operators, *and* prefix-unaries.
	#    This requires peek-ahead semantics to dispatch the token either to the number-parsing
	#    routines, or to their respective mathematical operators.
	#  - ZERO `0` may either a prefix-unary (for a non-decimal parsing op) *or* simply a trash
	#    character at the front of a base-10 integer. Again, peek-ahead solves this.
	# ~ec

	# FIXME: These may support the SYMBOL+(REG) syntax?

	# In my head, dis-interleaving these is more performant? :P ~ec
	slt $t0, $s0, 33
	slt $t1, $s0, 40
	slt $t2, $s0, 49
	slt $t3, $s0, 58
	slt $t4, $s0, 65
	slt $t5, $s0, 91
	slt $t6, $s0, 97
	slt $t7, $s0, 123
	slt $t8, $s0, 127

	bnez $t0, _dispatchToken__CONTROL
	bnez $t1, _dispatchToken__UNSUPPORTED
	bnez $t2, _dispatchToken__OTHER
	bnez $t3, _dispatchToken__DIGIT
	bnez $t4, _dispatchToken__UNSUPPORTED
	bnez $t5, _dispatchToken__WORD
	bnez $t6, _dispatchToken__UNSUPPORTED
	bnez $t7, _dispatchToken__WORD
	bnez $t8, _dispatchToken__UNSUPPORTED
	j _dispatchToken__CONTROL

_dispatchToken__OTHER:
	# Here we load the address of the first entry in the below dispatch-table; and then we
	# append the (offset) ASCII value of the character to the address, before jumping to the
	# computed result.
	la $t1, _dispatchToken__OTHER_table
	addi $s0, -40                           # index from the ASCII byte into [(, ), *, +, ...]
	mul $s0, $s0, 4
	add $s0, $s0, $t1                       # add that index to the address of our jump-table,
	jr $s0                                  # … jump into the computed address in our jump-table

_dispatchToken__OTHER_table:
	j _dispatchToken__BRACKETS      # (
	j _dispatchToken__BRACKETS      # )
	j _dispatchToken__ASTERISK      # *
	j _dispatchToken__PLUS          # +
	j _dispatchToken__COMMA         # ,
	j _dispatchToken__HYPHEN        # -
	j _dispatchToken__UNSUPPORTED   # .     # (unused)
	j _dispatchToken__SOLIDUS       # /
	j _dispatchToken__ZERO          # 0

_dispatchToken__COMMA:
	addi $a0, 1     # Increment cursor past the operator

	li $a1, 0
	jal consumeCharacters

	# Check for first quit command
	la $a1, quitCommandShort
	jal compareTokens
	bnez $v0, EXIT

	la $a1, quitCommandFull
	jal compareTokens
	bnez $v0, EXIT

	la $a1, helpCommandShort
	jal compareTokens
	bnez, $v0, printUsageMessage

	la $a1, helpCommandFull
	jal compareTokens
	bnez, $v0, printUsageMessage

	la $a1, helpCommandWTF
	jal compareTokens
	bnez, $v0, printUsageMessage

	j CONTINUE

_dispatchToken__PLUS:
	la $a1, performAdd
	j _dispatchToken__dispatchPossibleNumber

_dispatchToken__HYPHEN:
	la $a1, performSub
	j _dispatchToken__dispatchPossibleNumber

_dispatchToken__dispatchPossibleNumber:
	addi $t0, $a0, 1                        # Copy-and-increment cursor past the operator
	lb $t0, ($t0)                           # Peek the second character into $t0

	seq $t1, $t0, 32
	seq $t2, $t0, 10
	seq $t3, $t0, 9
	or $t0, $t1, $t2
	or $t0, $t0, $t3
	beqz $t0, _dispatchToken__DIGIT         # If the next character is *not* a space, number!

	addi $a0, 1                             # *Actually* increment cursor past the operator
	j _dispatchToken__dispatchBinaryOp

_dispatchToken__ASTERISK:
	addi $a0, 1                             # Increment cursor past the operator
	la $a1, performMul
	j _dispatchToken__dispatchBinaryOp

_dispatchToken__SOLIDUS:
	addi $a0, 1                             # Increment cursor past the operator
	la $a1, performDiv
	j _dispatchToken__dispatchBinaryOp

_dispatchToken__WORD:
	la $a1, hexOperatorShort
	jal compareTokens

	la $a1, performHexPrint
	bnez $v0, _dispatchToken__dispatchUnaryOp

	la $a1, binOperatorShort
	jal compareTokens
	move $s1, $v0
	la $a1, binOperatorFull
	jal compareTokens
	or $s1, $s1, $v0

	la $a1, performBinaryPrint
	bnez $s1, _dispatchToken__dispatchUnaryOp

	la $a1, decOperatorShort
	jal compareTokens
	move $s1, $v0
	la $a1, decOperatorFull
	jal compareTokens
	or $s1, $s1, $v0
	la $a1, peekOperatorFull
	jal compareTokens
	or $s1, $s1, $v0

	la $a1, performDecimalPrint
	bnez $s1, _dispatchToken__dispatchUnaryOp

	# intentional fall-through
_dispatchToken__unsupportedWord:
	jal extractTokenBounds
#	move $v0, $v0
#	move $v1, $v1

	la $a0, unsupportedOperationMessage
	jal printString

	move $a0, $v0
	addi $a1, $v1, 1
	jal printStringUpTo
	jal printNewline

	jal dumpRPNStack
	j CONTINUE

# Takes the address of a printing procedure on $a1
_dispatchToken__dispatchUnaryOp:
	la $a3, dispatchUnaryDescription
	jal printStringDEBUG

	move $s1, $a0
	move $t3, $a1                           # Expects a target operation's address in $a1

	li $a1, 1
	jal _dispatchToken__checkStackSize

	lw $a1, -4($s7)                                 # Load two stack-elements into arguments,
	jalr $t3
	sw $v0, -4($s7)                                 # replace the top item with the return-value

	move $a0, $s1
	jal extractTokenBounds
	addi $a0, $v1, 1

	j _dispatchToken__postlude

_dispatchToken__dispatchBinaryOp:
	la $a3, dispatchBinaryDescription
	jal printStringDEBUG

	# Expects a target operation's address in $a1
	move $t2, $a1

	li $a1, 2
	jal _dispatchToken__checkStackSize

	lw $a1, -8($s7)                                   # Load two stack-elements into arguments,
	lw $a2, -4($s7)

	jalr $t2

	addi $s7, -4                                    # shrink RPN stack by one slot,
	sw $v0, -4($s7)                                 # and replace the top item with the return-
	                                                # value of the operation
	j _dispatchToken__postlude

# Compares the stack-size to a minimum of $a1 elements
_dispatchToken__checkStackSize:
	mul $a1, $a1, 4

	la $t0, rpnStack
	blt $s7, $t0, WTF

	sub $t1, $s7, $a1
	blt $t1, $t0, _dispatchToken__tooFewOperands

	jr $ra

_dispatchToken__DIGIT:
	la $a1, WTF
	jal readDecimal

	move $s1, $v0
	la $v0, pushIntegerDescription
	move $a3, $s1
	jal printDescribedIntegerDEBUG

	sw $s1, ($s7)                                   # push the integer onto the stack
	addi $s7, 4
	j _dispatchToken__postlude

_dispatchToken__ZERO:
	addi $t0, $a0, 1                        # Copy-and-increment cursor past the operator
	lb $t0, ($t0)                           # Peek the second character into $t0

	seq $t1, $t0, 88                        # If the next character is an X
	seq $t2, $t0, 120                       #                       or an x
	or $t1, $t1, $t2
	bnez $t1, _dispatchToken__pushHex

	seq $t1, $t0, 66                        # If the next character is a B
	seq $t2, $t0, 98                        #                       or a b
	or $t1, $t1, $t2
	bnez $t1, _dispatchToken__pushBinary

	j _dispatchToken__DIGIT

_dispatchToken__pushHex:
	addi $a0, 2                             # *Actually* increment cursor past the operator

	la $a1, WTF
	jal readHex

	move $s1, $v0
	la $v0, pushIntegerDescription
	move $a3, $s1
	jal printDescribedIntegerDEBUG
	move $v0, $s1

	sw $s1, ($s7)                           # push the integer onto the stack
	addi $s7, 4
	j _dispatchToken__postlude

_dispatchToken__pushBinary:
	addi $a0, 2                             # *Actually* increment cursor past the operator

	la $a1, WTF
	jal readBinary

	move $s1, $v0
	la $v0, pushIntegerDescription
	move $a3, $s1
	jal printDescribedIntegerDEBUG
	move $v0, $s1

	sw $s1, ($s7)                                   # push the integer onto the stack
	addi $s7, 4
	j _dispatchToken__postlude

_dispatchToken__BRACKETS:
	move $t1, $a0
	la $a0, bracketsMessage
	jal printString

	move $a0, $t1
	jal printString
	jal printNewline

	j CONTINUE

_dispatchToken__UNSUPPORTED:
	move $t1, $a0

	la $a0, unsupportedOperationMessage
	jal printString

	move $a0, $t1
	addi $a1, $a0, 1
	jal printStringUpTo
	jal printNewline

	jal dumpRPNStack
	j CONTINUE

_dispatchToken__CONTROL:
	la $a0, unsupportedInputMessage
	jal printString
	jal printNewline

	j CONTINUE

_dispatchToken__tooFewOperands:
	move $t1, $a0

	la $a0, tooFewOperandsMessage
	jal printString

	move $a1, $t1
	addi $a0, $a1, -1                       # Yes, intentionally reading the *previous* char
	jal printStringUpTo
	jal printNewline

	jal dumpRPNStack
	j CONTINUE

_dispatchToken__postlude:
	lw $s1, -12($fp)
	lw $s0,  -8($fp)
	li $t9, 4
	j stackOUTAndReturn

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
