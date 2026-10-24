// tb_riscv.v - self-checking testbench for the single-cycle RV32I processor
// It runs tb/program.hex, watches for the store to data address 0xFFC and prints
//   PASS  (value 0x00C0FFEE)  or  FAIL at test N  (value N).
// It also writes a waveform file (riscv.vcd) for GTKWave.
//
// Run with Icarus Verilog from the project folder (A2_RISCV_Single_Cycle):
//   iverilog -g2005 -I rtl -o sim.out tb/tb_riscv.v rtl/*.v     (Git Bash / Linux)
//   PowerShell: replace rtl/*.v by the file list, e.g. (Get-ChildItem rtl\*.v).FullName
//   vvp sim.out
//   gtkwave riscv.vcd
`timescale 1ns/1ps

module tb_riscv;
    localparam RESULT_ADDR = 32'h0000_0FFC;
    localparam PASS_MAGIC  = 32'h00C0_FFEE;
    localparam MAX_CYCLES  = 5000;

    reg         clk = 1'b0;
    reg         reset = 1'b1;
    wire [31:0] pc, instr, dmem_addr, dmem_wdata;
    wire        dmem_we;
    wire [3:0]  dmem_byte_en;
    integer     cycles = 0;

    riscv_single_cycle #(.MEM_FILE("tb/program.hex")) dut (
        .clk(clk), .reset(reset),
        .pc_out(pc), .instr_out(instr),
        .dmem_we(dmem_we), .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata), .dmem_byte_en(dmem_byte_en)
    );

    always #5 clk = ~clk;                       // 100 MHz clock (10 ns period)

    initial begin
        $dumpfile("riscv.vcd");
        $dumpvars(0, tb_riscv);
        #12 reset = 1'b0;                       // release reset between clock edges
    end

    // check on every rising edge, before the store is written into memory
    always @(posedge clk) begin
        if (!reset) begin
            cycles = cycles + 1;
            if (dmem_we && dmem_addr == RESULT_ADDR) begin
                if (dmem_wdata == PASS_MAGIC)
                    $display("PASS: all tests passed in %0d cycles", cycles);
                else
                    $display("FAIL at test %0d (pc = %h) after %0d cycles",
                             dmem_wdata, pc, cycles);
                $finish;
            end
            if (cycles >= MAX_CYCLES) begin
                $display("TIMEOUT: no result after %0d cycles (pc = %h)", cycles, pc);
                $finish;
            end
        end
    end
endmodule
