// load_store.v - byte/halfword handling between the core and the word-wide data memory
// Store side: makes the byte enables and puts the data in the correct byte lane.
// Load side : picks the addressed byte/halfword and sign- or zero-extends it.
// Assumption: accesses are naturally aligned (sh/lh/lhu on even addresses,
// sw/lw on multiples of 4). Misaligned accesses are not supported.
module load_store (
    input  wire [2:0]  funct3,
    input  wire [1:0]  addr_lo,     // ALUResult[1:0] = byte offset inside the word
    input  wire        mem_write,
    input  wire [31:0] store_data,  // rs2
    input  wire [31:0] mem_rdata,   // word read from dmem
    output reg  [3:0]  byte_en,
    output reg  [31:0] mem_wdata,
    output reg  [31:0] load_data
);
    wire [31:0] shifted = mem_rdata >> {addr_lo, 3'b000};   // addr_lo * 8

    // ---------- store ----------
    always @(*) begin
        byte_en   = 4'b0000;
        mem_wdata = store_data;
        if (mem_write) begin
            case (funct3[1:0])
                2'b00: begin                                   // sb
                    byte_en   = 4'b0001 << addr_lo;
                    mem_wdata = {4{store_data[7:0]}};
                end
                2'b01: begin                                   // sh
                    byte_en   = addr_lo[1] ? 4'b1100 : 4'b0011;
                    mem_wdata = {2{store_data[15:0]}};
                end
                default: begin                                 // sw
                    byte_en   = 4'b1111;
                    mem_wdata = store_data;
                end
            endcase
        end
    end

    // ---------- load ----------
    always @(*) begin
        case (funct3)
            3'b000:  load_data = {{24{shifted[7]}},  shifted[7:0]};    // lb
            3'b001:  load_data = {{16{shifted[15]}}, shifted[15:0]};   // lh
            3'b010:  load_data = mem_rdata;                            // lw
            3'b100:  load_data = {24'b0, shifted[7:0]};                // lbu
            3'b101:  load_data = {16'b0, shifted[15:0]};               // lhu
            default: load_data = mem_rdata;
        endcase
    end
endmodule
