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
include(Math.m4.asm)
include(Eval.m4.asm)
include(Main.m4.asm)

.data

# Global toggle for all debugging-output; switch to `1` to enable.
DEBUGenable:
	.byte 0

quitCommandShort:
	.asciiz "q\n"

quitCommandLong:
	.asciiz "quit\n"

dnl vim: set shiftwidth=8 tabstop=8 noexpandtab softtabstop& list listchars=tab\: ·:
