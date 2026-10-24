// dmem.v - data memory (combinational read, synchronous write with byte enables)
// 1024 words = 4 KiB, byte addresses 0x000 - 0xFFF.
// byte_en[k] = 1 writes byte k of the word (k = 0 is the least significant byte,
// because RISC-V is little-endian).
module dmem #(
    parameter WORDS = 1024
) (
    input  wire        clk,
    input  wire        we,
    input  wire [3:0]  byte_en,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);
    reg [31:0] ram [0:WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            ram[i] = 32'h0000_0000;
    end

    // read-modify-write of one word (portable: no part-select on an array element)
    reg [31:0] w;
    always @(posedge clk) begin
        if (we) begin
            w = ram[addr[11:2]];
            if (byte_en[0]) w[7:0]   = wdata[7:0];
            if (byte_en[1]) w[15:8]  = wdata[15:8];
            if (byte_en[2]) w[23:16] = wdata[23:16];
            if (byte_en[3]) w[31:24] = wdata[31:24];
            ram[addr[11:2]] <= w;
        end
    end

    assign rdata = ram[addr[11:2]];
endmodule
