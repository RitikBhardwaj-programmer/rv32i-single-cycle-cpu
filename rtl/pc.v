// pc.v - program counter register (module program_counter)
// On reset the PC goes to 0 (address of the first instruction).
// On every rising clock edge it loads the next PC chosen by the datapath.
module program_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);
    always @(posedge clk or posedge reset) begin
        if (reset) pc <= 32'h0000_0000;
        else       pc <= pc_next;
    end
endmodule
