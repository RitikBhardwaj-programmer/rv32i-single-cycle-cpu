// control.v - main decoder: opcode -> datapath control signals
// fence, ecall, ebreak and unknown opcodes produce all-zero controls,
// so they behave as NOPs (no register or memory write, PC + 4).
`include "riscv_defs.vh"

module control (
    input  wire [6:0] opcode,
    output reg        reg_write,
    output reg  [2:0] imm_src,
    output reg  [1:0] alu_src_a,
    output reg        alu_src_b,    // 0 = rs2, 1 = immediate
    output reg        mem_write,
    output reg  [1:0] result_src,
    output reg        branch,
    output reg        jump,         // jal
    output reg        jalr,
    output reg  [1:0] alu_op
);
    always @(*) begin
        // defaults = NOP
        reg_write  = 1'b0;
        imm_src    = `IMM_I;
        alu_src_a  = `SRCA_RS1;
        alu_src_b  = 1'b0;
        mem_write  = 1'b0;
        result_src = `RES_ALU;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        alu_op     = `ALUOP_ADD;

        case (opcode)
            `OP_R: begin
                reg_write = 1'b1;
                alu_op    = `ALUOP_FUNCT;
            end
            `OP_I_ALU: begin
                reg_write = 1'b1;
                imm_src   = `IMM_I;
                alu_src_b = 1'b1;
                alu_op    = `ALUOP_FUNCT;
            end
            `OP_LOAD: begin
                reg_write  = 1'b1;
                imm_src    = `IMM_I;
                alu_src_b  = 1'b1;
                result_src = `RES_MEM;
            end
            `OP_STORE: begin
                imm_src   = `IMM_S;
                alu_src_b = 1'b1;
                mem_write = 1'b1;
            end
            `OP_BRANCH: begin
                imm_src = `IMM_B;
                branch  = 1'b1;
                alu_op  = `ALUOP_BRANCH;
            end
            `OP_JAL: begin
                reg_write  = 1'b1;
                imm_src    = `IMM_J;
                result_src = `RES_PC4;
                jump       = 1'b1;
            end
            `OP_JALR: begin
                reg_write  = 1'b1;
                imm_src    = `IMM_I;
                alu_src_b  = 1'b1;
                result_src = `RES_PC4;
                jalr       = 1'b1;
            end
            `OP_LUI: begin
                reg_write = 1'b1;
                imm_src   = `IMM_U;
                alu_src_a = `SRCA_ZERO;
                alu_src_b = 1'b1;
            end
            `OP_AUIPC: begin
                reg_write = 1'b1;
                imm_src   = `IMM_U;
                alu_src_a = `SRCA_PC;
                alu_src_b = 1'b1;
            end
            default: ;  // OP_FENCE, OP_SYSTEM, unknown -> NOP
        endcase
    end
endmodule
