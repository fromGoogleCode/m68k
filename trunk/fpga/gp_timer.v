`timescale 1ns / 1ps

/*
   Periodic 16-bit timer module
   Author: ljalvs@gmail.com
   
   This module provides a periodic timer controller.

   Address mapping in bus_ctrl.v
   BASE_ADDR+0 - reload value[1]
   BASE_ADDR+1 - reload value[0]
   BASE_ADDR+2 - current value[1]
   BASE_ADDR+3 - current value[0]

   To reset the interrupt flag, a write to the control
   reg is required.
   
   2012.05.08, ljalvs@gmail.com, Created.
	2012.11.14, ljalvs@gmail.com, Modified to from 24-bit to 16-bit.
                                 24-bit counter was overkill and
											was wasting fpga CLBs

*/

module gp_timer(
	// system
	input wire clk,
	input wire tclk,
	input wire rst_n,
	
	// to bus_ctrl
	input wire [15:0] preset,
	output wire [15:0] value,
	input wire en,
	input wire rst_int_n,
	
	// module specific
	output reg int_n

);

	reg [15:0] counter;
	wire [15:0] n_counter;
	assign n_counter = counter[15:0] - 16'h1;
	assign value[15:0] = preset[15:0] - counter[15:0];
	
	/*wire en = ctrl_in[0];*/
	
	/*assign ctrl_out = {~int_n, ctrl_in[6:0]};*/
	
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
