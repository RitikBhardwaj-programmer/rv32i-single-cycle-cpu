#!/usr/bin/env python3
"""rv32i_iss.py - instruction-set simulator (golden reference model) for RV32I.

Usage:  python rv32i_iss.py program.hex [max_steps]

It decodes the machine code directly (it does not share code with the assembler),
runs it with the same memory map as the Verilog design, and stops when the program
writes to the result address 0xFFC. It prints PASS/FAIL, the final registers and
how many times each instruction ran (instruction coverage).
"""
import sys
from collections import Counter

RESULT_ADDR = 0xFFC
PASS_MAGIC = 0x00C0FFEE
MASK = 0xFFFFFFFF


def sx(val, bits):
    val &= (1 << bits) - 1
    return val - (1 << bits) if val >> (bits - 1) else val


def s32(v):
    return sx(v, 32)


class ISS:
    def __init__(self, words):
        self.imem = words
        self.dmem = bytearray(4096)
        self.x = [0] * 32
        self.pc = 0
        self.cov = Counter()
        self.result = None

    def lw(self, a):
        a &= 0xFFF
        return int.from_bytes(self.dmem[a:a + 4], "little")

    def load(self, a, n, signed):
        a &= 0xFFF
        v = int.from_bytes(self.dmem[a:a + n], "little")
        return sx(v, 8 * n) & MASK if signed else v

    def store(self, a, v, n):
        a &= 0xFFF
        self.dmem[a:a + n] = (v & ((1 << (8 * n)) - 1)).to_bytes(n, "little")
        if a == RESULT_ADDR:
            self.result = v & MASK

    def step(self):
        ins = self.imem[(self.pc >> 2) & 0x3FF] if (self.pc >> 2) < len(self.imem) else 0x13
        op = ins & 0x7F
        rd = (ins >> 7) & 0x1F
        f3 = (ins >> 12) & 7
        rs1 = (ins >> 15) & 0x1F
        rs2 = (ins >> 20) & 0x1F
        f7 = ins >> 25
        a, b = self.x[rs1], self.x[rs2]
        imm_i = sx(ins >> 20, 12)
        imm_s = sx(((ins >> 25) << 5) | ((ins >> 7) & 0x1F), 12)
        imm_b = sx((((ins >> 31) & 1) << 12) | (((ins >> 7) & 1) << 11) |
                   (((ins >> 25) & 0x3F) << 5) | (((ins >> 8) & 0xF) << 1), 13)
        imm_u = ins & 0xFFFFF000
        imm_j = sx((((ins >> 31) & 1) << 20) | (((ins >> 12) & 0xFF) << 12) |
                   (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1), 21)
        nxt = (self.pc + 4) & MASK
        wb = None

        if op == 0x33:                                   # R-type
            name = {(0, 0): "add", (0x20, 0): "sub", (0, 1): "sll", (0, 2): "slt",
                    (0, 3): "sltu", (0, 4): "xor", (0, 5): "srl", (0x20, 5): "sra",
                    (0, 6): "or", (0, 7): "and"}[(f7, f3)]
            wb = self.alu(name, a, b)
        elif op == 0x13:                                 # I-type ALU
            if f3 == 1:
                name, wb = "slli", self.alu("sll", a, rs2)
            elif f3 == 5:
                name = "srai" if f7 == 0x20 else "srli"
                wb = self.alu("sra" if f7 == 0x20 else "srl", a, rs2)
            else:
                name = {0: "addi", 2: "slti", 3: "sltiu", 4: "xori", 6: "ori", 7: "andi"}[f3]
                wb = self.alu(name[:-1] if name != "sltiu" else "sltu", a, imm_i & MASK)
        elif op == 0x03:                                 # loads
            addr = (a + imm_i) & MASK
            name, n, sg = {0: ("lb", 1, True), 1: ("lh", 2, True), 2: ("lw", 4, False),
                           4: ("lbu", 1, False), 5: ("lhu", 2, False)}[f3]
            wb = self.load(addr, n, sg)
        elif op == 0x23:                                 # stores
            addr = (a + imm_s) & MASK
            name, n = {0: ("sb", 1), 1: ("sh", 2), 2: ("sw", 4)}[f3]
            self.store(addr, b, n)
        elif op == 0x63:                                 # branches
            name, take = {0: ("beq", a == b), 1: ("bne", a != b),
                          4: ("blt", s32(a) < s32(b)), 5: ("bge", s32(a) >= s32(b)),
                          6: ("bltu", a < b), 7: ("bgeu", a >= b)}[f3]
            if take:
                nxt = (self.pc + imm_b) & MASK
        elif op == 0x6F:
            name, wb, nxt = "jal", nxt, (self.pc + imm_j) & MASK
        elif op == 0x67:
            name, wb, nxt = "jalr", nxt, ((a + imm_i) & MASK) & ~1
        elif op == 0x37:
            name, wb = "lui", imm_u
        elif op == 0x17:
            name, wb = "auipc", (self.pc + imm_u) & MASK
        elif op == 0x0F:
            name = "fence"
        elif op == 0x73:
            name = "ebreak" if (ins >> 20) == 1 else "ecall"
        else:
            raise RuntimeError(f"illegal instruction {ins:08x} at pc {self.pc:08x}")

        if wb is not None and rd != 0:
            self.x[rd] = wb & MASK
        self.cov[name] += 1
        self.pc = nxt

    @staticmethod
    def alu(name, a, b):
        sh = b & 0x1F
        return {"add": a + b, "sub": a - b, "and": a & b, "or": a | b, "xor": a ^ b,
                "sll": a << sh, "srl": a >> sh, "sra": s32(a) >> sh,
                "slt": int(s32(a) < s32(b)), "sltu": int(a < b)}[name] & MASK


ALL_RV32I = ["lui", "auipc", "jal", "jalr", "beq", "bne", "blt", "bge", "bltu", "bgeu",
             "lb", "lh", "lw", "lbu", "lhu", "sb", "sh", "sw",
             "addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli", "srai",
             "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and",
             "fence", "ecall", "ebreak"]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    with open(sys.argv[1]) as f:
        words = [int(l, 16) for l in f if l.strip()]
    max_steps = int(sys.argv[2]) if len(sys.argv) > 2 else 10000
    sim = ISS(words)
    steps = 0
    while sim.result is None and steps < max_steps:
        sim.step()
        steps += 1
    if sim.result is None:
        print(f"TIMEOUT after {steps} instructions (pc = {sim.pc:08x})")
        sys.exit(2)
    ok = sim.result == PASS_MAGIC
    print(("PASS" if ok else f"FAIL at test {sim.result}") + f" after {steps} instructions")
    print("final registers:")
    for i in range(0, 32, 4):
        print("  " + "  ".join(f"x{j:<2}={sim.x[j]:08x}" for j in range(i, i + 4)))
    missing = [n for n in ALL_RV32I if sim.cov[n] == 0]
    print(f"instruction coverage: {len(ALL_RV32I) - len(missing)}/{len(ALL_RV32I)}"
          + (f"  missing: {missing}" if missing else ""))
    print("  " + ", ".join(f"{n}:{sim.cov[n]}" for n in ALL_RV32I))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
