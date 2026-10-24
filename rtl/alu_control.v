// alu_control.v - ALU decoder
// Turns ALUOp (from the main decoder) plus funct3 / funct7[5] into the ALU operation.
//   op_b5 = instr[5] tells R-type (1) from I-type (0). Only R-type can mean SUB,
//   because in addi the bit instr[30] is part of the immediate, not funct7.
//   For shifts, instr[30] picks arithmetic (sra/srai) or logical (srl/srli) right shift.
`include "riscv_defs.vh"

module alu_control (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire       funct7_b5,   // instr[30]
    input  wire       op_b5,       // instr[5]
    output reg  [3:0] alu_ctrl
);
    always @(*) begin
        case (alu_op)
            `ALUOP_ADD:    alu_ctrl = `ALU_ADD;
            `ALUOP_BRANCH: alu_ctrl = `ALU_SUB;
            `ALUOP_FUNCT: begin
                case (funct3)
                    3'b000:  alu_ctrl = (op_b5 & funct7_b5) ? `ALU_SUB : `ALU_ADD;
                    3'b001:  alu_ctrl = `ALU_SLL;
                    3'b010:  alu_ctrl = `ALU_SLT;
                    3'b011:  alu_ctrl = `ALU_SLTU;
                    3'b100:  alu_ctrl = `ALU_XOR;
                    3'b101:  alu_ctrl = funct7_b5 ? `ALU_SRA : `ALU_SRL;
                    3'b110:  alu_ctrl = `ALU_OR;
                    3'b111:  alu_ctrl = `ALU_AND;
                    default: alu_ctrl = `ALU_ADD;
                endcase
            end
            default:       alu_ctrl = `ALU_ADD;
        endcase
    end
endmodule
