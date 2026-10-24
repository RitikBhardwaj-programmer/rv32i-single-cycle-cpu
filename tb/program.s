# program.s - self-checking test program for the single-cycle RV32I processor
#
# Convention:
#   x10 = value produced by the instruction under test
#   x11 = expected value
#   x28 = number of the current test
# Every check is:  li x11, EXPECTED / li x28, N / bne x10, x11, fail
# At the end the program stores a result word at data address 0xFFC:
#   0x00C0FFEE  -> all tests passed
#   N           -> test N failed
# The testbench watches that address and prints PASS or FAIL.

# ---------------- operands used by many tests ----------------
        li   x1, -8                 # x1 = 0xFFFFFFF8
        li   x2, 3                  # x2 = 3

# ---------------- U-type ----------------
        lui  x10, 0x12345           # T1  lui
        li   x11, 0x12345000
        li   x28, 1
        bne  x10, x11, fail

        auipc x5, 0                 # T2  auipc: two auipc 4 bytes apart differ by 4
        auipc x6, 0
        sub  x10, x6, x5
        li   x11, 4
        li   x28, 2
        bne  x10, x11, fail

        auipc x6, 0                 # T3  auipc with a non-zero immediate:
        auipc x7, 1                 #     (A+4 + 0x1000) - A = 0x1004
        sub  x10, x7, x6
        li   x11, 0x1004
        li   x28, 3
        bne  x10, x11, fail

# ---------------- I-type ALU ----------------
        addi x10, x1, 5             # T4  -8 + 5 = -3
        li   x11, -3
        li   x28, 4
        bne  x10, x11, fail

        slti x10, x1, 0             # T5  -8 < 0 (signed) -> 1
        li   x11, 1
        li   x28, 5
        bne  x10, x11, fail

        sltiu x10, x1, 5            # T6  0xFFFFFFF8 < 5 (unsigned)? no -> 0
        li   x11, 0
        li   x28, 6
        bne  x10, x11, fail

        xori x10, x1, -1            # T7  NOT(-8) = 7
        li   x11, 7
        li   x28, 7
        bne  x10, x11, fail

        ori  x10, x2, 0x10          # T8  3 | 0x10 = 0x13
        li   x11, 0x13
        li   x28, 8
        bne  x10, x11, fail

        andi x10, x1, 0x0F          # T9  0xFFFFFFF8 & 0xF = 8
        li   x11, 8
        li   x28, 9
        bne  x10, x11, fail

        slli x10, x2, 4             # T10 3 << 4 = 48
        li   x11, 48
        li   x28, 10
        bne  x10, x11, fail

        srli x10, x1, 28            # T11 logical shift: 0xF
        li   x11, 0xF
        li   x28, 11
        bne  x10, x11, fail

        srai x10, x1, 2             # T12 arithmetic shift: -8 >> 2 = -2
        li   x11, -2
        li   x28, 12
        bne  x10, x11, fail

# ---------------- R-type ----------------
        add  x10, x1, x2            # T13 -8 + 3 = -5
        li   x11, -5
        li   x28, 13
        bne  x10, x11, fail

        sub  x10, x2, x1            # T14 3 - (-8) = 11
        li   x11, 11
        li   x28, 14
        bne  x10, x11, fail

        sll  x10, x2, x2            # T15 3 << 3 = 24
        li   x11, 24
        li   x28, 15
        bne  x10, x11, fail

        slt  x10, x1, x2            # T16 -8 < 3 (signed) -> 1
        li   x11, 1
        li   x28, 16
        bne  x10, x11, fail

        sltu x10, x1, x2            # T17 0xFFFFFFF8 < 3 (unsigned)? no -> 0
        li   x11, 0
        li   x28, 17
        bne  x10, x11, fail

        xor  x10, x1, x2            # T18 0xFFFFFFF8 ^ 3 = 0xFFFFFFFB
        li   x11, 0xFFFFFFFB
        li   x28, 18
        bne  x10, x11, fail

        srl  x10, x1, x2            # T19 0xFFFFFFF8 >> 3 = 0x1FFFFFFF
        li   x11, 0x1FFFFFFF
        li   x28, 19
        bne  x10, x11, fail

        sra  x10, x1, x2            # T20 -8 >>> 3 = -1
        li   x11, -1
        li   x28, 20
        bne  x10, x11, fail

        or   x10, x1, x2            # T21 0xFFFFFFF8 | 3 = 0xFFFFFFFB
        li   x11, 0xFFFFFFFB
        li   x28, 21
        bne  x10, x11, fail

        and  x10, x1, x2            # T22 0xFFFFFFF8 & 3 = 0
        li   x11, 0
        li   x28, 22
        bne  x10, x11, fail

        addi x0, x0, 5              # T23 writes to x0 are ignored
        add  x10, x0, x0
        li   x11, 0
        li   x28, 23
        bne  x10, x11, fail

# ---------------- loads and stores ----------------
        li   x20, 0x200             # base address of the test data
        li   x3, 0x8BADF00D
        sw   x3, 0(x20)             # mem[0x200] = 0x8BADF00D (bytes 0D F0 AD 8B)

        lw   x10, 0(x20)            # T24 lw
        li   x11, 0x8BADF00D
        li   x28, 24
        bne  x10, x11, fail

        lb   x10, 0(x20)            # T25 lb, positive byte 0x0D
        li   x11, 0x0D
        li   x28, 25
        bne  x10, x11, fail

        lb   x10, 3(x20)            # T26 lb, negative byte 0x8B -> sign-extended
        li   x11, 0xFFFFFF8B
        li   x28, 26
        bne  x10, x11, fail

        lbu  x10, 3(x20)            # T27 lbu, zero-extended
        li   x11, 0x8B
        li   x28, 27
        bne  x10, x11, fail

        lh   x10, 2(x20)            # T28 lh upper half 0x8BAD -> sign-extended
        li   x11, 0xFFFF8BAD
        li   x28, 28
        bne  x10, x11, fail

        lhu  x10, 2(x20)            # T29 lhu upper half
        li   x11, 0x8BAD
        li   x28, 29
        bne  x10, x11, fail

        lh   x10, 0(x20)            # T30 lh lower half 0xF00D -> sign-extended
        li   x11, 0xFFFFF00D
        li   x28, 30
        bne  x10, x11, fail

        li   x4, 0x11223344
        sw   x0, 4(x20)             # clear mem[0x204]
        sb   x4, 5(x20)             # byte 1 = 0x44
        lw   x10, 4(x20)            # T31 sb into the middle of a word
        li   x11, 0x00004400
        li   x28, 31
        bne  x10, x11, fail

        sh   x4, 6(x20)             # upper half = 0x3344
        lw   x10, 4(x20)            # T32 sh into the upper half
        li   x11, 0x33444400
        li   x28, 32
        bne  x10, x11, fail

        addi x21, x20, 16           # x21 = 0x210
        sw   x2, -4(x21)            # negative store offset -> mem[0x20C] = 3
        lw   x10, 12(x20)           # T33 negative S-immediate
        li   x11, 3
        li   x28, 33
        bne  x10, x11, fail

# ---------------- branches (taken and not taken) ----------------
        li   x28, 34                # T34 beq taken
        beq  x1, x1, ok34
        j    fail
ok34:   li   x28, 35                # T35 beq not taken
        beq  x1, x2, fail

        li   x28, 36                # T36 bne taken
        bne  x1, x2, ok36
        j    fail
ok36:   li   x28, 37                # T37 bne not taken
        bne  x1, x1, fail

        li   x28, 38                # T38 blt taken (-8 < 3)
        blt  x1, x2, ok38
        j    fail
ok38:   li   x28, 39                # T39 blt not taken (3 < -8 is false)
        blt  x2, x1, fail

        li   x28, 40                # T40 bge taken (3 >= -8)
        bge  x2, x1, ok40
        j    fail
ok40:   li   x28, 41                # T41 bge taken on equal
        bge  x1, x1, ok41
        j    fail
ok41:   li   x28, 42                # T42 bge not taken (-8 >= 3 is false)
        bge  x1, x2, fail

        li   x28, 43                # T43 bltu taken (3 < 0xFFFFFFF8)
        bltu x2, x1, ok43
        j    fail
ok43:   li   x28, 44                # T44 bltu not taken
        bltu x1, x2, fail

        li   x28, 45                # T45 bgeu taken (0xFFFFFFF8 >= 3)
        bgeu x1, x2, ok45
        j    fail
ok45:   li   x28, 46                # T46 bgeu not taken
        bgeu x2, x1, fail

        li   x5, 0                  # T47 backward branch: sum 1..5 = 15
        li   x6, 1
        li   x7, 6
loop:   add  x5, x5, x6
        addi x6, x6, 1
        bne  x6, x7, loop
        add  x10, x5, x0
        li   x11, 15
        li   x28, 47
        bne  x10, x11, fail

# ---------------- jumps ----------------
        jal  x9, func               # T48 jal to a subroutine, jalr back
        li   x11, 0x55
        li   x28, 48
        bne  x10, x11, fail

        auipc x5, 0                 # T49 jal link value = address of jal + 4
        jal  x9, next49             #     (auipc at A, jal at A+4, link = A+8)
next49: sub  x10, x9, x5
        li   x11, 8
        li   x28, 49
        bne  x10, x11, fail

        auipc x5, 0                 # T50 jalr clears bit 0 of the target
        addi x5, x5, 16             # x5 = A+16
        jalr x6, 1(x5)              # rs1+imm = A+17 (odd) -> target A+16, link x6 = A+12
        j    fail                   # A+12: must be skipped
        sub  x10, x6, x5            # A+16: (A+12) - (A+16) = -4
        li   x11, -4
        li   x28, 50
        bne  x10, x11, fail

# ---------------- fence / ecall / ebreak behave as NOPs ----------------
        li   x10, 0x77              # T51
        fence
        ecall
        ebreak
        li   x11, 0x77
        li   x28, 51
        bne  x10, x11, fail

# ---------------- all tests passed ----------------
pass:   li   x5, 0x00C0FFEE
        li   x6, 0xFFC
        sw   x5, 0(x6)
done:   j    done

fail:   li   x6, 0xFFC
        sw   x28, 0(x6)
hang:   j    hang

# subroutine used by T48
func:   li   x10, 0x55
        jalr x0, 0(x9)
