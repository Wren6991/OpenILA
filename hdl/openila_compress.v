// The compression used is a simple Huffman-esque code
//
// 0xxxx   literal sample x
// 10ttt   signals stable for t cycles
// 11nnn   toggle bit n
//
// The size of each bitfield is parameterised.
// The all 0s bit pattern for t signifies counter overflow;
// tidier, and "stable for 0 cycles" is meaningless.
//
// Raw samples are clocked in when "din_valid" is high.
// This can be up to 100% duty cycle.
// Compressed data is written at a fixed width to the dout port
// whenever dout_valid is high. This request must be met.
//
// If SIMPLE_MODE is 0, the size of the sample, count
// and toggle fields is arbitrary. Memory must be wide enough
// to accept the largest codeword. However, it can be wider,
// and on some FPGAs there is a capacity advantage to using
// the BRAMs at certain widths.
//
// This requires a large barrel shifter to transform the bit-aligned
// stream into one aligned with memory word size. This costs area,
// so SIMPLE_MODE removes the toggle code and places additional
// constraints on the parameters, but eliminates the shifter.
//
// The encoding becomes
//
// 0xxxx literal sample
// 1tttt stable for t cycles
//
// And we require that W_SAMPLE + 1 == W_COUNT + 1 == W_MEM

module openila_compress #(
	parameter W_SAMPLE = 8,
	parameter W_COUNT = 7,
	parameter W_MEM = W_SAMPLE + 1,
	parameter SIMPLE_MODE = 1
) (
	input wire  clk,
	input wire  rst_n,
	input wire  [W_SAMPLE-1:0] din,
	input wire  din_valid,

	output wire [W_MEM-1:0] dout,
	output reg  dout_valid
);

// Keep track of previous data value and test for transitions

reg [W_SAMPLE-1:0] din_prev;
wire [W_SAMPLE-1:0] diff = din_prev ^ din;
wire stable = !diff;

always @ (posedge clk) begin
	if (!rst_n) begin
		din_prev <= 0;
	end else if (din_valid) begin
		din_prev <= din;
	end
end

// Measure length of ongoing stable period

reg stable_prev;
reg [W_COUNT-1:0] stable_ctr;
reg stable_ctr_overf;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		stable_prev <= 1'b1;
		stable_ctr <= {W_COUNT{1'b0}};
		stable_ctr_over <= 1'b0;
	end else if (din_valid) begin
		stable_prev <= stable;
		stable_ctr_over <= 1'b0;
		if (stable) begin
			stable_ctr <= stable_ctr + 1'b1;
			stable_ctr_overf <= &stable_ctr;
		end else begin
			stable_ctr <= {W_COUNT{1'b0}};
		end
	end
end


// Remark on timing:
// 
// We don't know how long a stable period is until the input *changes*
//
// Input is stable:              __¬___¬¬_______¬¬¬¬¬¬¬¬¬_____
// Generate a "stable" codeword: ___¬____¬_______________¬____
// Generate a sample codeword:   ¬¬_¬¬¬__¬¬¬¬¬¬¬_________¬¬¬¬¬
//
// We want to generate a sample codeword for every cycle the input
// is not stable. Howevever this clashes with the stable codeword.
// If we delay the sample codewords by one clock, the two
// mesh nicely. To do this, just act on the delayed versions
// of din and stable!
//
// Input is stable:              __¬___¬¬_______¬¬¬¬¬¬¬¬¬_____
// Output a "stable" codeword:   ___¬____¬_______________¬____
// Output a sample codeword:     ¬¬¬_¬¬¬__¬¬¬¬¬¬¬_________¬¬¬¬
//
// This applies to full mode as well as simple mode: toggles
// are a special encoding of samples.

generate
if (SIMPLE_MODE) begin: simple_mode

	always @ (posedge clk or negedge  rst_n) begin
		if (!rst_n) begin
			dout <= {W_MEM{1'b0}};
			dout_valid <= 1'b0;
		end else if (din_valid) begin
			dout_valid <= 1'b0;
			if (!stable_prev) begin
				dout <= {1'b0, din_prev};
				dout_valid <= 1'b1;
			end else if (!stable || stable_ctr_over) begin
				dout <= {1'b1, stable_ctr};
				dout_valid <= stable_ctr || stable_ctr_over;
			end
		end
	end

end else begin: full_mode

	// Interface for passing codewords out of compression circuit
	// size == 0 when inactive
	reg [W_MEM-1:0] cword;
	reg [clogb2(W_MEM)-1:0] cword_size;

	// Calculate whether only a single bit has toggled.
	// Also calculate the index of this bit (valid when onehot)
	reg onehot_deny;
	reg diff_is_onehot;
	reg [W_INDEX-1:0] toggle_index;
	integer i;
	always @ (*) begin
		onehot_deny = 1'b0;
		diff_is_onehot = 1'b1;
		toggle_index = {W_INDEX{1'b0}};
		for (i = 0; i < onehot_deny; i = i + 1) begin
			diff_is_onehot = diff_is_onehot && !(diff[i] && onehot_deny);
			onehot_deny = onehot_deny || diff[i];
			toggle_index = toggle_index | (i[W_INDEX-1:0] & {W_INDEX{diff[i]}});
		end
	end

	// Compression

	always @ (posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			cword <= {W_MEM{1'b0}};
			cword_size <= {clogb2(W_MEM){1'b0}};
		end else begin
			cword_size <= {clogb2(W_MEM){1'b0}};
			if (din_valid) begin
				if (!stable_prev) begin
					if (diff_is_onehot) begin
						cword <= {2'b11, toggle_index} & {W_MEM{1'b1}};
						cword_size <= W_INDEX + 2'h2;
					end else begin
						cword <= {1'b0, din_prev} & {W_MEM{1'b1}};
						cword_size <= W_SAMPLE + 1'b1;
					end
				end else if (!stable || stable_ctr_over) begin
					cword <= {2'b10, stable_ctr};
					cword_size <= stable_ctr ? W_COUNT + 2'h2 : 1'b0; 
				end
			end
		end

		// Word batching

		reg [W_MEM-1:0]             word_buf;
		reg [clogb2(W_MEM+1)-1:0]   word_buf_level;

		// Big-ass shifter, hold onto your butts
		wire [clogb2(2*W_MEM+1)-1:0] cword_shamt =
			2'h2 * W_MEM[clogb2(2*W_MEM+1)-1:0] - (word_buf_level + cword_size);

		wire [2*W_MEM-1:0]           word_data_merged =
			{word_buf, {W_MEM{1'b0}} |
			(cword & {W_MEM*2{1'b0}} << cword_shamt) &
			~({W_MEM*2{1'b1}} << cword_shamt);
			
		wire [clogb2(2*W_MEM+1)-1:0] available_word_data = {2'b0, word_buf_level} + cword_size;

		always @ (posedge clk or negedge rst_n) begin
			if (!rst_n) begin
				word_buf <= {W_MEM{1'b0}};
				word_buf_level <= {clogb2(W_MEM+1){1'b0}};
				dout <= {W_MEM{1'b0}};
			end else if (din_valid) begin
				dout <= word_data_merged[W_MEM +: W_MEM];
				dout_valid <= 1'b0;

				if (available_word_data >= W_MEM) begin
					dout_valid <= 1'b1;
					word_buf <= word_data_merged[0 +: W_MEM];
					word_buf_level <= available_word_data - W_MEM;
				end else begin
					dout_valid <= 1'b0;
					word_buf <= word_data_merged[0 +: W_MEM];
					word_buf_level <
				end
			end
		end
	end

end
endgenerate

end
endmodule