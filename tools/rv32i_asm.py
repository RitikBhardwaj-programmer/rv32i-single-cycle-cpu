#!/usr/bin/env python3
"""rv32i_asm.py - tiny two-pass RV32I assembler for the test program.

Usage:  python rv32i_asm.py program.s program.hex [program.lst]

Supports all RV32I instructions plus the pseudo-instructions
  li rd, imm   (always lui + addi, so every li is 8 bytes)
  j label      (jal x0, label)
  nop          (addi x0, x0, 0)
Registers: x0..x31 or ABI names (zero, ra, sp, ...). Comments start with '#'.
"""
import re
import sys

ABI = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1",
       "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7",
       "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11",
       "t3", "t4", "t5", "t6"]

R_OPS = {  # name: (funct7, funct3)
    "add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1), "slt": (0x00, 2),
    "sltu": (0x00, 3), "xor": (0x00, 4), "srl": (0x00, 5), "sra": (0x20, 5),
    "or": (0x00, 6), "and": (0x00, 7)}
I_ALU = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
SHIFT_I = {"slli": (0x00, 1), "srli": (0x00, 5), "srai": (0x20, 5)}
LOADS = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORES = {"sb": 0, "sh": 1, "sw": 2}
BRANCHES = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}


def reg(tok):
    tok = tok.strip()
    if tok in ABI:
        return ABI.index(tok)
    if tok == "fp":
        return 8
    m = re.fullmatch(r"x(\d+)", tok)
    if not m or int(m.group(1)) > 31:
        raise ValueError(f"bad register '{tok}'")
    return int(m.group(1))


def num(tok):
    return int(tok.strip(), 0)


def check_range(val, bits, signed, what):
    lo, hi = (-(1 << (bits - 1)), (1 << (bits - 1)) - 1) if signed else (0, (1 << bits) - 1)
    if not lo <= val <= hi:
        raise ValueError(f"{what} {val} out of range [{lo}, {hi}]")


def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    check_range(imm, 12, True, "I-immediate")
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3, op):
    check_range(imm, 12, True, "S-immediate")
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op


def enc_b(off, rs2, rs1, f3, op):
    check_range(off, 13, True, "branch offset")
    if off & 1:
        raise ValueError("branch offset must be even")
    o = off & 0x1FFF
    return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | op


def enc_u(imm20, rd, op):
    check_range(imm20, 20, False, "U-immediate")
    return (imm20 << 12) | (rd << 7) | op


def enc_j(off, rd, op):
    check_range(off, 21, True, "jump offset")
    o = off & 0x1FFFFF
    return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | \
           (((o >> 12) & 0xFF) << 12) | (rd << 7) | op


def split_li(val):
    val &= 0xFFFFFFFF
    hi = ((val + 0x800) >> 12) & 0xFFFFF
    lo = val - (hi << 12)
    lo = ((lo + 0x800) & 0xFFF) - 0x800          # sign-extended 12-bit value
    return hi, lo


def parse(lines):
    """Pass 1: strip comments, collect labels, expand sizes."""
    items, labels, pc = [], {}, 0
    for lineno, raw in enumerate(lines, 1):
        line = raw.split("#")[0].strip()
        while ":" in line:
            lab, line = line.split(":", 1)
            labels[lab.strip()] = pc
            line = line.strip()
        if not line:
            continue
        mn, _, rest = line.partition(" ")
        args = [a.strip() for a in rest.split(",")] if rest.strip() else []
        size = 8 if mn == "li" else 4
        items.append((pc, mn, args, lineno, line))
        pc += size
    return items, labels


def mem_arg(tok):
    m = re.fullmatch(r"(-?\w+)\((\w+)\)", tok.replace(" ", ""))
    if not m:
        raise ValueError(f"bad memory operand '{tok}'")
    return num(m.group(1)), reg(m.group(2))


def assemble_one(pc, mn, a, labels):
    def target(tok):
        return (labels[tok] if tok in labels else num(tok)) - pc

    if mn in R_OPS:
        f7, f3 = R_OPS[mn]
        return [enc_r(f7, reg(a[2]), reg(a[1]), f3, reg(a[0]), 0x33)]
    if mn in I_ALU:
        return [enc_i(num(a[2]), reg(a[1]), I_ALU[mn], reg(a[0]), 0x13)]
    if mn in SHIFT_I:
        f7, f3 = SHIFT_I[mn]
        sh = num(a[2])
        check_range(sh, 5, False, "shift amount")
        return [enc_r(f7, sh, reg(a[1]), f3, reg(a[0]), 0x13)]
    if mn in LOADS:
        off, base = mem_arg(a[1])
        return [enc_i(off, base, LOADS[mn], reg(a[0]), 0x03)]
    if mn in STORES:
        off, base = mem_arg(a[1])
        return [enc_s(off, reg(a[0]), base, STORES[mn], 0x23)]
    if mn in BRANCHES:
        return [enc_b(target(a[2]), reg(a[1]), reg(a[0]), BRANCHES[mn], 0x63)]
    if mn == "jal":
        if len(a) == 1:
            a = ["x1"] + a
        return [enc_j(target(a[1]), reg(a[0]), 0x6F)]
    if mn == "jalr":
        off, base = mem_arg(a[1])
        return [enc_i(off, base, 0, reg(a[0]), 0x67)]
    if mn == "lui":
        return [enc_u(num(a[1]), reg(a[0]), 0x37)]
    if mn == "auipc":
        return [enc_u(num(a[1]), reg(a[0]), 0x17)]
    if mn == "fence":
        return [0x0FF0000F]                 # fence iorw, iorw
    if mn == "ecall":
        return [0x00000073]
    if mn == "ebreak":
        return [0x00100073]
    # pseudo-instructions
    if mn == "li":
        hi, lo = split_li(num(a[1]))
        rd = reg(a[0])
        return [enc_u(hi, rd, 0x37), enc_i(lo, rd, 0, rd, 0x13)]
    if mn == "j":
        return [enc_j(target(a[0]), 0, 0x6F)]
    if mn == "nop":
        return [0x00000013]
    raise ValueError(f"unknown mnemonic '{mn}'")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, out = sys.argv[1], sys.argv[2]
    lst = sys.argv[3] if len(sys.argv) > 3 else None
    with open(src) as f:
        items, labels = parse(f.readlines())
    words, listing = [], []
    for pc, mn, args, lineno, text in items:
        try:
            ws = assemble_one(pc, mn, args, labels)
        except (ValueError, KeyError, IndexError) as e:
            sys.exit(f"{src}:{lineno}: {e}  ->  {text}")
        for k, w in enumerate(ws):
            listing.append(f"{pc + 4 * k:08x}:  {w:08x}    {text if k == 0 else '  (cont.)'}")
        words.extend(ws)
    with open(out, "w", newline="\n") as f:
        f.write("\n".join(f"{w:08x}" for w in words) + "\n")
    if lst:
        with open(lst, "w", newline="\n") as f:
            f.write("\n".join(listing) + "\n")
    print(f"assembled {len(words)} words ({4 * len(words)} bytes) -> {out}")


if __name__ == "__main__":
    main()
