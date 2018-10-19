module openila_core #(
	parameter W_SAMPLE = 8,
	parameter W_COUNT = 8,
	parameter SIMPLE_MODE = 1,
	parameter W_MEM = W_SAMPLE + 1,
	parameter W_ADDR = 8
) (
	input wire clk,
	input wire rst_n,

	input wire [W_SAMPLE-1:0] probe,

	// Generic byte-serial I/O for control interface
	input wire [7:0] comm_in,
	input wire comm_in_valid,
	output reg comm_in_ready,

	output reg [7:0] comm_out,
	output reg comm_out_valid,
	input wire comm_out_ready
);

`include "openila_functions.vh"

openila_trigger #(
	.W_DATA(W_SAMPLE)
) inst_openila_trigger (
	.clk         (clk),
	.rst_n       (rst_n),
	.sample      (probe),
	// .trigger     (trigger),
	// .stage1_val  (stage1_val),
	// .stage1_mask (stage1_mask),
	// .stage2_val  (stage2_val),
	// .stage2_mask (stage2_mask)
);


openila_compress #(
	.W_SAMPLE(W_SAMPLE),
	.W_COUNT(W_COUNT),
	.W_MEM(W_SAMPLE + 1),
	.SIMPLE_MODE(SIMPLE_MODE)
) inst_openila_compress (
	.clk        (clk),
	.rst_n      (rst_n),
	// .din        (din),
	// .din_valid  (din_valid),
	// .dout       (dout),
	// .dout_valid (dout_valid)
);


openila_mem #(
	.W_DATA(W_MEM),
	.W_ADDR(W_ADDR)
) inst_openila_mem (
	.clk   (clk),
	// .addr  (addr),
	// .wen   (wen),
	// .wdata (wdata),
	// .rdata (rdata)
);

endmodule