# RIBBN User's Manual #

## Overview ##
RIBBN is an interactive calculator REPL (Read-Evaluate-Print-Loop) which utilizes Reverse Polish Notation (RPN). You can enter math expressions in RPN and have them evaluated. `,quit` exits RIBBN and `,help` prints more detailed usage information.

## User Interface and RPN ##
RIBBN uses the postfix [Reverse Polish Notation](https://en.wikipedia.org/wiki/Reverse_Polish_notation) (RPN) to represent mathematical expressions. RPN is compact, expressive, and in some cases more explicit than a more standard infix notation.

In RPN, calculations are entered with two operands followed by an operator. For instance:

	=) 123 456 +
	=O 579

Compound expressions can be written in the same manner.

	=) 123 456 + 789 * 			# Equivalent to (123 + 456) * 789 in infix notation
	=O 456831

It is also possible to chain operators together, in effect achieving inside-out evaluation.

	=) 123 456 789 + * 			# Equivalent to (456 + 789) * 123 in infix notation
	=O 153135

Using RPN, one can avoid most of the usual cases where paranthesis are required, while still maintaining readability.

	=) 12 34 + 56 78 + *		# Equivalent to (12 + 34) * (56 + 78) in infix notation
	=O 6164

RIBBN runs a Read-Eval-Print-Loop which continually evaluates new RPN expressions and prints their results. In addition to RPN expressions, RIBBN supports a set of special commands prefixed by the `,` character.

## Numeric Representation and Acceptable Numbers ##
RIBBN internally uses two's complement signed 32-bit integers for all calculations. Thus, representable numbers are in the range -2,147,483,648 to 2,147,483,647. If overflow occurs during a calculation, it will be aborted and an error message with the problematic operation will be displayed.

RIBBN supports multiple textual numeric representations. Decimal integers may contain commas and be prefixed with a minus (`-`) sign. Binary numbers are prefaced with `0b` and hexadecimal numbers are prefaced with `0x`. Binary and hexadecimal numbers translate directly to bits in a two's complement binary string, and therefore have no regular "negativity" support (they cannot be prefaced with `-` signs).

As examples, the following numbers are all valid input to RIBBN:

	123,456,789
	123456789
	-487
	0xfce
	0b111100101

While these numbers are not:
	
	123.456
	-0xfce
	-0b111100101

Numbers entered that are not internally representable will result in overflow errors.

## Operator Listing ##

### `<a> <b> +` ###
Adds `<a>` and `<b>`.

### `<a> <b> -` ###
Subtracts `<a>` from `<b>`.

### `<a> <b> *` ###
Multiplies `<a>` and `<b>`.

### `<a> <b> /` ###
Divides `<a>` by `<b>`.

### `<a> BIN` ###
Prints `<a>` as a binary string and passes it through the RPN expression.

### `<a> HEX` ###
Prints `<a>` as a hexadecimal string and passes it through the RPN expression.

### `<a> DEC` ###
Prints `<a>` as a decimal string and passes it through the RPN expression.

## Command Listing ##

### `,q` and `,quit` ###
Exits RIBBN.

### `,h` and `,help` ###
Prints a usage message.

### `,debug` ###
Toggles debug output.