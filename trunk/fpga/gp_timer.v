/*
   Periodic 24-bit timer module
   Author: ljalvs@gmail.com
   
   This module provides a periodic timer controller.

   Address mapping
   BASE_ADDR+0 - control: (IF),X,X,X,X,X,X,EN
   BASE_ADDR+1 - counter[2]
   BASE_ADDR+2 - counter[1]
   BASE_ADDR+3 - counter[0]
   BASE_ADDR+4 -
   BASE_ADDR+5 - current value[2]
   BASE_ADDR+6 - current value[1]
   BASE_ADDR+7 - current value[0]
   
   (n) - Read only bit
   
   To reset the interrupt flag, a write to the control
   reg is required.
   
   2012.05.08, ljalvs@gmail.com, Created.

*/

module gp_timer(
	// system
	input wire clk,
	input wire tclk,
	input wire rst_n,
	
	// to bus_ctrl
	input wire [23:0] preset,
	output wire [23:0] value,
	input wire [7:0] ctrl_in,
	output wire [7:0] ctrl_out,
	input wire rst_int_n,
	
	// module specific
	output reg int_n




);

	reg [23:0] counter;
	wire [23:0] n_counter;
	assign n_counter = counter[23:0] + 24'h1;

	assign value = counter;
	
	wire en = ctrl_in[0];
	
	assign ctrl_out = {~int_n, ctrl_in[6:0]};
	
	always @(posedge tclk)
		if (en) begin
			if (~|counter)
				counter <= preset;
			else
				counter <= n_counter;
		end else begin
			counter <= preset;
		end

		
	always @(negedge clk or negedge rst_n)
		if (!rst_n) begin
			int_n <= 1;
		end else begin
			if (~rst_int_n)
				int_n <= 1;
			else if (~|counter)
				int_n <= ~en;
		end

endmodule
