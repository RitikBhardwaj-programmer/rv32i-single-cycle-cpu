// riscv_single_cycle.v - top level of the single-cycle RV32I processor
// Every instruction is fetched, decoded, executed, and written back in ONE clock cycle.
// Memories are separate (Harvard): instruction memory and data memory can both be
// accessed in the same cycle.
`include "riscv_defs.vh"

module riscv_single_cycle #(
    parameter MEM_FILE = "program.hex"
) (
    input  wire        clk,
    input  wire        reset,
    // debug / testbench visibility
    output wire [31:0] pc_out,
    output wire [31:0] instr_out,
    output wire        dmem_we,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_byte_en
);
    // ---------------- wires ----------------
    wire [31:0] pc, pc_next, pc_plus4, pc_target;
    wire [31:0] instr;
    wire [31:0] rs1_data, rs2_data, imm_ext;
    wire [31:0] src_a, src_b, alu_result;
    wire [31:0] mem_rdata, mem_wdata, load_data;
    wire [3:0]  byte_en;
    reg  [31:0] result;
    wire [3:0]  alu_ctrl;
    wire        take;

    // control signals
    wire        reg_write, alu_src_b, mem_write, branch, jump, jalr;
    wire [2:0]  imm_src;
    wire [1:0]  alu_src_a, result_src, alu_op;

    // instruction fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];

    // ---------------- fetch ----------------
    program_counter u_pc (.clk(clk), .reset(reset), .pc_next(pc_next), .pc(pc));

    imem #(.MEM_FILE(MEM_FILE)) u_imem (.addr(pc), .instr(instr));

    assign pc_plus4  = pc + 32'd4;
    assign pc_target = pc + imm_ext;                 // branch and jal target

    // ---------------- decode ----------------
    control u_ctrl (
        .opcode(opcode), .reg_write(reg_write), .imm_src(imm_src),
        .alu_src_a(alu_src_a), .alu_src_b(alu_src_b), .mem_write(mem_write),
        .result_src(result_src), .branch(branch), .jump(jump), .jalr(jalr),
        .alu_op(alu_op)
    );

    regfile u_rf (
        .clk(clk), .we(reg_write), .ra1(rs1), .ra2(rs2), .wa(rd),
        .wd(result), .rd1(rs1_data), .rd2(rs2_data)
    );

    imm_gen u_imm (.instr(instr), .imm_src(imm_src), .imm_ext(imm_ext));

    // ---------------- execute ----------------
    alu_control u_aluctl (
        .alu_op(alu_op), .funct3(funct3), .funct7_b5(instr[30]),
        .op_b5(instr[5]), .alu_ctrl(alu_ctrl)
    );

    assign src_a = (alu_src_a == `SRCA_PC)   ? pc :
                   (alu_src_a == `SRCA_ZERO) ? 32'h0000_0000 :
                                               rs1_data;
    assign src_b = alu_src_b ? imm_ext : rs2_data;

    alu u_alu (.a(src_a), .b(src_b), .alu_ctrl(alu_ctrl), .result(alu_result));

    branch_unit u_br (.funct3(funct3), .a(rs1_data), .b(rs2_data), .take(take));

    // next PC: jalr -> (rs1 + imm) with bit 0 cleared; jal / taken branch -> PC + imm
    assign pc_next = jalr                    ? {alu_result[31:1], 1'b0} :
                     (jump | (branch & take)) ? pc_target :
                                                pc_plus4;

    // ---------------- memory ----------------
    load_store u_ls (
        .funct3(funct3), .addr_lo(alu_result[1:0]), .mem_write(mem_write),
        .store_data(rs2_data), .mem_rdata(mem_rdata),
        .byte_en(byte_en), .mem_wdata(mem_wdata), .load_data(load_data)
    );

    dmem u_dmem (
        .clk(clk), .we(mem_write), .byte_en(byte_en), .addr(alu_result),
        .wdata(mem_wdata), .rdata(mem_rdata)
    );

    // ---------------- write-back ----------------
    always @(*) begin
        case (result_src)
            `RES_MEM: result = load_data;
            `RES_PC4: result = pc_plus4;
            default:  result = alu_result;
        endcase
    end

    // ---------------- debug outputs ----------------
    assign pc_out       = pc;
    assign instr_out    = instr;
    assign dmem_we      = mem_write;
    assign dmem_addr    = alu_result;
    assign dmem_wdata   = mem_wdata;
    assign dmem_byte_en = byte_en;
endmodule
