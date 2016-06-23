FILE(<!CONVERSION.M4.ASM!>)

  .data

lineBuffer:
  .space 1024

overflowMessage:
  .asciiz "Overflow!!!\n"

stringifyHexLUT:
  .ascii "0123456789ABCDEF"

newline:
  .asciiz "\n"

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
  .byte 8

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

# === readBinary == #
# @leaf
# @param  $a0  Pointer to string to parse as binary, moved in-place
# @param  $a1  Jump target for overflows
# @return $v0  Parsed binary number
readBinary:
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

handleOverflow:
  li $v0, 4
  la $a0, overflowMessage
  syscall
  j main

main:
  li $v0, 5
  syscall

  la $a1, lineBuffer
  move $a0, $v0
  jal stringifyHex

  li $v0, 4
  la $a0, lineBuffer
  syscall

  la $a0, newline
  syscall

  j main
