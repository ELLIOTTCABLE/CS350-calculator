FILE(<!CONVERSION.M4.ASM!>)

  .data

stringifyHexLUT:
  .ascii "0123456789ABCDEF"

readHexLUT:
      #  0  1  2  3  4  5  6  7  8  9
  .byte  0  1  2  3  4  5  6  7  8  9
      #  :  ;  <  =  >  ?  @
  .byte -1 -1 -1 -1 -1 -1 -1
      #  A  B  C  D  E  F
  .byte 10 11 12 13 14 15
      #  G  H  I  J  K  L  M  N  O  P  Q  R  S  T  U  V  W  X  Y  Z  [  \  ]  ^  _  `
  .byte -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
      #  a  b  c  d  e  f
  .byte 10 11 12 13 14 15


readHexBuffer:
  .space 8

readIntegerBuffer: # Used for parsing integers
  .space 10

  .text

# === stringifyBinary == #
# @leaf
# @param $a0  Number to stringify into a string representing a binary number
# @param $a1  Pointer to start address of produced string
stringifyBinary:
  li $t0, 0x80000000
  li $t9, 1

  j _stringifyBinaryLoop

_stringifyBinaryLoop:
  beq $t0, $zero, _stringifyBinaryExit

  and $t1, $a0, $t0
  sne $t1, $t1, $zero
  addiu $t1, 48
  sb $t1, ($a1)

  srl $t0, $t0, $t9
  addiu $a1, 1

  j _stringifyBinaryLoop

_stringifyBinaryExit:
  sb $zero, ($a1)
  jr $ra

# === stringifyHex == #
# @leaf
# @param $a0  Number to stringify into a string representing a hexadecimal number
# @param $a1  Pointer to start address of produced string
stringifyHex:
  li $t0, 0xF0000000
  li $t1, 28
  li $t9, 4

  j _stringifyHexLoop

_stringifyHexLoop:
  beq $t0, $zero, _stringifyHexExit

  and $t2, $a0, $t0
  srl $t2, $t2, $t1

  lb $t2, stringifyHexLUT+0($t2)
  sb $t2, ($a1)

  srl $t0, $t0, $t9
  addi $t1, -4
  addiu $a1, 1

  j _stringifyHexLoop

_stringifyHexExit:
  sb $zero, ($a1)
  jr $ra

# === skipZeros == #
# @leaf
# @param  $a0  Pointer to string with zero or more zeros to skip, moved in-place
# @param  $a1  Continuation target after zeros are skipped
# @stomps $t0
skipZeros:
  lb $t0, ($a0)
  bne $t0, 48, _skipZerosExit
  addiu $a0, 1
  j skipZeros
_skipZerosExit:
  jr $a1

# === readBinary == #
# @leaf
# @param  $a0  Pointer to string to parse as binary, moved in-place
# @param  $a1  Jump target for overflows
# @return $v0  Parsed binary number
readBinary:
  move $t1, $a1
  la $a1, _readBinaryCount
  j skipZeros

_readBinaryCount:
  move $a1, $t1
  li $t0, 0
  j _readBinaryCountLoop

_readBinaryCountLoop:
  lb $t1, ($a0)

  sne $t2, $t1, 48
  sne $t3, $t1, 49
  and $t2, $t2, $t3
  bnez $t2, _readBinarySum

  beq $t0, 32, _readBinaryOverflow

  addiu $t0, 1
  addiu $a0, 1

  j _readBinaryCountLoop

_readBinarySum:
  li $v0, 0
  subu $a0, $a0, $t0
  addi $t0, -1

  j _readBinarySumLoop

_readBinarySumLoop:
  beq $t0, -1, _readBinaryExit

  lb $t1, ($a0)
  addi $t1, -48
  sll $t1, $t1, $t0
  addu $v0, $v0, $t1

  addi $t0, -1
  addiu $a0, 1

  j _readBinarySumLoop

_readBinaryOverflow:
  jr $a1

_readBinaryExit:
  jr $ra

# === readHex == #
# @leaf
# @param  $a0  Pointer to string to parse as hex, moved in-place
# @param  $a1  Jump target for overflows
# @return $v0  Parsed hexadecimal number
readHex:
  move $t1, $a1
  la $a1, _readHexRead
  j skipZeros

_readHexRead:
  move $a1, $t1
  li $t0, 0
  j _readHexReadLoop

_readHexReadLoop:
  lb $t1, ($a0)

  slt $t2, $t1, 48        # "0"
  sgt $t3, $t1, 102       # "f"
  or $t2, $t2, $t3
  bnez $t2, _readHexSum

  addi $t1, -48
  lb $t2, readHexLUT+0($t1)
  beq $t2, -1, _readHexSum

  beq $t0, 8, _readHexOverflow

  sb $t2, readHexBuffer+0($t0)

  addiu $t0, 1
  addiu $a0, 1

  j _readHexReadLoop

_readHexSum:
  li $v0, 0
  addi $t0, -1
  li $t1, 1
  li $t2, 16

  j _readHexSumLoop

_readHexSumLoop:
  beq $t0, -1, _readHexExit

  lb $t3, readHexBuffer+0($t0)
  multu $t3, $t1
  mflo $t3
  addu $v0, $v0, $t3

  addi $t0, -1
  multu $t1, $t2
  mflo $t1

  j _readHexSumLoop

_readHexOverflow:
  jr $a1

_readHexExit:
  jr $ra

# ### readInteger ###
# @leaf
# @param  $a0   start of string to parse as integer
# @param  $a1   Jump target for overflows
# @return $v0   parsed integer
# @stomps $t0..9

readInteger:
  move $t1, $a1
  la $a1, _readIntegerRead
  j skipZeros

_readIntegerRead:
  move $a1, $t1

  la $t0, readIntegerBuffer               # Pointer to current read location
  addiu $t1, $t0, 10                      # Pointer to one past end of buffer (end of read)

  # Next-level hacking for negative numbers (not really)
  lb $t2, ($a0)
  li $t3, 1
  li $t4, -2
  li $t5, 45 # "-" character
  seq $t5, $t2, $t5
  add $a0, $a0, $t5
  mul $t4, $t5, $t4
  add $t9, $t3, $t4

  j _readIntegerReadLoop               # Jump into loop

_readIntegerReadLoop:
  lb $t2, ($a0)                           # Load next character from string
  addi $t2, -48                           # Offset ASCII value to get numerical value

  # Check if it's within the range of ASCII digits
  # If not, branch to the summation step
  li $t3, -1
  sgt $t3, $t2, $t3
  li $t4, 10
  slt $t4, $t2, $t4
  and $t3, $t3, $t4
  beqz $t3, _readIntegerSum

  beq $t0, $t1, _readIntegerOverflow      # Jump to overflow if we're past 10 digits

  sb $t2, ($t0)                           # Store numerical value in buffer
  addiu $t0, 1                            # Increment buffer pointer
  addiu $a0, 1                            # Increment string pointer

  j _readIntegerReadLoop                  # Loop back

_readIntegerSum:
  li $v0, 0                               # Initialize accumulation register

  # Pointer to one before start of buffer (end of read)
  la $t1, readIntegerBuffer
  addi $t1, -1

  # Step the write head backwards, since we stop one past the buffer
  addi $t0, -1

  # Initialize registers for multiplication
  li $t2, 1
  li $t3, 10

  j _readIntegerSumLoop                   # Jump to summation loop

_readIntegerSumLoop:
  beq $t0, $t1, _readIntegerReturn        # Branch to return when done reading

  # Load byte and multiply by current place value
  lb $t4, ($t0)
  multu $t4, $t2
  mflo $t5
  mfhi $t6
  slt $t7, $t5, $zero
  sne $t8, $t6, $zero
  or $t7, $t7, $t8
  bnez $t7, _readIntegerOverflow         # Overflow check

  # Accumulate into $v0
  addu $v0, $v0, $t5
  bltz $v0, _readIntegerOverflow         # Overflow check

  mul $t2, $t2, $t3                      # Increase place value
  addi $t0, -1                           # Decrement read pointer
  j _readIntegerSumLoop                  # Loop back

_readIntegerOverflow:
  jr $a1

_readIntegerReturn:
  mul $v0, $v0, $t9
  jr $ra