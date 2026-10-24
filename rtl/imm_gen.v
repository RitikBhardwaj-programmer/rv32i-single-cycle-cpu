// imm_gen.v - immediate generator (sign-extends the immediate of each format)
//   I : instr[31:20]
//   S : instr[31:25] | instr[11:7]
//   B : instr[31] | instr[7] | instr[30:25] | instr[11:8] | 0
//   U : instr[31:12] | 12'b0
//   J : instr[31] | instr[19:12] | instr[20] | instr[30:21] | 0
`include "riscv_defs.vh"

module imm_gen (
    input  wire [31:0] instr,
    input  wire [2:0]  imm_src,
    output reg  [31:0] imm_ext
);
    always @(*) begin
        case (imm_src)
            `IMM_I:  imm_ext = {{20{instr[31]}}, instr[31:20]};
            `IMM_S:  imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            `IMM_B:  imm_ext = {{19{instr[31]}}, instr[31], instr[7],
                                instr[30:25], instr[11:8], 1'b0};
            `IMM_U:  imm_ext = {instr[31:12], 12'b0};
            `IMM_J:  imm_ext = {{11{instr[31]}}, instr[31], instr[19:12],
                                instr[20], instr[30:21], 1'b0};
            default: imm_ext = 32'h0000_0000;
        endcase
    end
endmodule
