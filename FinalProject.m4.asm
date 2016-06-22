# Lucas Myers and ELLIOTTCABLE
# Final Project.m4.asm

changequote(<!,!>)
include(Utility.m4.asm)
include(ProcessInput.m4.asm)
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
