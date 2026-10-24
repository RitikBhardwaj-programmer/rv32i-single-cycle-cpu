`ifndef RISCV_DEFS_VH
`define RISCV_DEFS_VH

// riscv_defs.vh - shared constants for the single-cycle RV32I processor

// ---------------- Opcodes (instr[6:0]) ----------------
`define OP_R      7'b0110011   // add, sub, sll, slt, sltu, xor, srl, sra, or, and
`define OP_I_ALU  7'b0010011   // addi, slti, sltiu, xori, ori, andi, slli, srli, srai
`define OP_LOAD   7'b0000011   // lb, lh, lw, lbu, lhu
`define OP_STORE  7'b0100011   // sb, sh, sw
`define OP_BRANCH 7'b1100011   // beq, bne, blt, bge, bltu, bgeu
`define OP_JAL    7'b1101111   // jal
`define OP_JALR   7'b1100111   // jalr
`define OP_LUI    7'b0110111   // lui
`define OP_AUIPC  7'b0010111   // auipc
`define OP_FENCE  7'b0001111   // fence      (executed as NOP)
`define OP_SYSTEM 7'b1110011   // ecall/ebreak (executed as NOP)

// ---------------- Immediate formats (ImmSrc) ----------------
`define IMM_I 3'd0
`define IMM_S 3'd1
`define IMM_B 3'd2
`define IMM_U 3'd3
`define IMM_J 3'd4

// ---------------- ALU operations (ALUControl) ----------------
`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_AND  4'd2
`define ALU_OR   4'd3
`define ALU_XOR  4'd4
`define ALU_SLL  4'd5
`define ALU_SRL  4'd6
`define ALU_SRA  4'd7
`define ALU_SLT  4'd8
`define ALU_SLTU 4'd9

// ---------------- ALUOp (main decoder -> ALU decoder) ----------------
`define ALUOP_ADD    2'b00     // address / PC arithmetic: always add
`define ALUOP_BRANCH 2'b01     // branches (compare done in branch_unit)
`define ALUOP_FUNCT  2'b10     // R-type and I-type ALU: look at funct3/funct7

// ---------------- ALU operand A select (ALUSrcA) ----------------
`define SRCA_RS1  2'b00
`define SRCA_PC   2'b01        // auipc
`define SRCA_ZERO 2'b10        // lui

// ---------------- Write-back select (ResultSrc) ----------------
`define RES_ALU 2'b00
`define RES_MEM 2'b01
`define RES_PC4 2'b10          // jal, jalr: rd = PC + 4

`endif // RISCV_DEFS_VH
