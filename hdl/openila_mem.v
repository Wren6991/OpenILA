// Simple behavioural memory model for OpenILA.
// Also provides insertion point for vendor macros if needed

module openila_mem #(
	parameter W_DATA = 8,
	parameter W_ADDR = 8,
	parameter MEM_DEPTH = 1 << W_ADDR
) (
	input wire               clk,
	input wire  [W_ADDR-1:0] addr,
	input wire               wen,
	input wire  [W_DATA-1:0] wdata,
	output reg [W_DATA-1:0] rdata
);

reg [W_DATA-1:0] mem [MEM_DEPTH-1:0];

always @ (posedge clk) begin
	rdata <= mem[addr];
	if (wen)
		mem[addr] <= wdata;
end

endmodule