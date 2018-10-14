// Trigger condition is a two-stage ternary match.
// This allows any combination of edge and level to be matched on.
//
// Query is combinatorial; trigger output goes high on the same clock
// that sample is presented.
//
// Since the trigger is a 2 stage state machine, it could
// miss events if in the wrong state when a triggering event
// occurs. This is solved with two state machines which are
// in alternate lockstep, and the outputs ORed.


module openila_trigger #(
	parameter W_DATA = 8
) (
	input wire              clk,
	input wire              rst_n,

	input wire [W_DATA-1:0] sample,
	output wire             trigger,

	input wire [W_DATA-1:0] stage1_val,
	input wire [W_DATA-1:0] stage1_mask,
	input wire [W_DATA-1:0] stage2_val,
	input wire [W_DATA-1:0] stage2_mask
);

wire match_stage1 = !((stage1_val ^ sample) & stage1_mask);
wire match_stage2 = !((stage2_val ^ sample) & stage2_mask);

// state is simply which trigger stage we are at
reg sm1_state;
reg sm2_state;

assign trigger = match_stage2 && (sm1_state || sm2_state);

// Logic for the two triggering state machines
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sm1_state <= 1'b0;
		sm2_state <= 1'b0;
	end else begin
		if (sm1_state) begin
			sm1_state <= 1'b0;
		end else begin
			sm1_state <= match_stage1;
		end
		if (sm2_state) begin
			sm2_state <= 1'b0;
		end else begin
			// Only trigger when other SM is in stage 2; fill blind spots.
			sm2_state <= match_stage1 && sm1_state;
		end
	end
end

`ifdef FORMAL

initial assume(!rst_n);

always @ (posedge clk) begin
	assume(rst_n);
	// Check that the interleaved state machines cover all valid trigger timings
	if ($past(match_stage1) && match_stage2)
		assert(trigger);
end

`endif // FORMAL

endmodule