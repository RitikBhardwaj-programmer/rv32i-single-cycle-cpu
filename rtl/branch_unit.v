// branch_unit.v - decides whether a conditional branch is taken
// funct3: 000 beq, 001 bne, 100 blt, 101 bge, 110 bltu, 111 bgeu
module branch_unit (
    input  wire [2:0]  funct3,
    input  wire [31:0] a,       // rs1
    input  wire [31:0] b,       // rs2
    output reg         take
);
    always @(*) begin
        case (funct3)
            3'b000:  take = (a == b);
            3'b001:  take = (a != b);
            3'b100:  take = ($signed(a) <  $signed(b));
            3'b101:  take = ($signed(a) >= $signed(b));
            3'b110:  take = (a <  b);
            3'b111:  take = (a >= b);
            default: take = 1'b0;
        endcase
    end
endmodule
