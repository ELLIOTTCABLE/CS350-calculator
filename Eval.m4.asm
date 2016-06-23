FILE(<!EVAL.M4.ASM!>)

.data
rpnStack: # Storage for up to 64 stack-operations
	.space 256 # 4 * 64

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


# ### dispatchToken ###
# @non-leaf
# @param  $a0   address of the first character (non-whitespace) of a token
# @param  $a1   address of the  character (non-whitespace) of a token
# @return $a0   (MODIFIED) address of the first character (whitespace) *after* the token

 dispatchToken:
_dispatchToken__prelude:
	# NOTE: I'm confused about the conventions w.r.t the frame-pointer; it seems that, generally
	#       speaking, $fp should point to the *start* of the stack-frame (i.e. the value of $sp
	#       before any manipulation.) However, this required me to save the value of the
	#       caller's existing $fp somewhere temporary, so I can replace it, and that was a waste
	#       of quite a few instructions; so I opted to store that *guaranteed* word (caller's
	#       frame- pointer) *before* our frame-pointer (i.e. at `-4($fp)`). Thus, arguments
	#       passed to us on the stack begin with `-8($fp)` instead of the obvious `-4($fp)`.
	#       (This, as far as I can tell, matches the x86 calling-convention.) ~ec
	addi $sp, $sp, -16      # Allocate stack space for four 4-byte items:
	sw $fp, 12($sp)         # caller's $fp,
	move $fp, $sp
	sw $ra, -0($fp)         # caller's $ra,
	sw $s0, -4($fp)         # caller's $s0,
	sw $s1, -8($fp)         # caller's $s1.
	# intentional fall-through

_dispatchToken__check:
	lb $s0, ($a0)                           # Load the first character into $s0
	addi $a0, 1                             # Increment the read-cursor

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
	slt $t8, $s0, 123

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
	addi $s0, -42                           # index from the ASCII byte into [*, +, _, -, _, /]
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

# NYI: dispatches to separate command-dispatcher
_dispatchToken__COMMA:

# NYI: peek at subsequent character, then dispatch either to unary-dispatcher or to decimal-parser
_dispatchToken__PLUS:
_dispatchToken__HYPHEN:
_dispatchToken__ZERO:

# NYI: dispatch to math routines
_dispatchToken__ASTERISK:
_dispatchToken__SOLIDUS:

# NYI: dispatch to operation-lookup (BIN, HEX, ADD, etc)
_dispatchToken__WORD:

# NYI: dispatch to integer parser
_dispatchToken__DIGIT:

# NYI: error message that this is RPN, i.e. try re-ordering
_dispatchToken__BRACKETS:

# NYI: error message that this token represents unsupported behaviour
_dispatchToken__UNSUPPORTED:

# NYI: error message that that this is an erranous input byte (control character, or higher-plane)
_dispatchToken__CONTROL:

_dispatchToken__postlude:
	lw $s1, -8($fp)
	lw $s0, -4($fp)
	lw $ra, -0($fp)
	lw $fp,  4($fp) # loads the old fp *based on* the current fp
	addi $sp, $sp, 16

	jr $ra

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
