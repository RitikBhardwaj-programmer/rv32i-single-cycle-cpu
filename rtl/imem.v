// imem.v - instruction memory (read-only, combinational read)
// 1024 words = 4 KiB. The program is loaded from a hex file (one 32-bit word per line).
// Address bits [1:0] are ignored because every instruction is word aligned.
module imem #(
    parameter MEM_FILE = "program.hex",
    parameter WORDS    = 1024
) (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] rom [0:WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            rom[i] = 32'h0000_0013;          // fill with NOP (addi x0, x0, 0)
        $readmemh(MEM_FILE, rom);
    end

    assign instr = rom[addr[11:2]];
endmodule
