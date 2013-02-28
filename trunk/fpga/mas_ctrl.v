`timescale 1ns / 1ps
/*
   SPI controller module
   Author: ljalvs@gmail.com
   
   Simple SPI controller

   2012.05.15, ljalvs@gmail.com, Created.

*/

module mas_ctrl(
	input wire clk,
	input wire rst_n,
	
	// cpu bus interface
	input wire [15:0] datain,
	output wire [15:0] dataout,
	input wire wr_n,

	// spi physical interface
	output wire mosi,
	output reg sclk,
	input wire busy,
);


	reg [1:0] state;
	reg [7:0] treg;
	assign mosi = treg[7];


	// low byte = control
	// high byte = data

	wire en;
	wire [1:0] div;
	wire spi_busy;
	assign spi_busy = |state;
	
	assign div  = datain[1:0];
	//assign cs_n = ~datain[4];
	assign en   = datain[5];
	
	
	assign dataout[7:0] = {spi_busy, busy, datain[5:0]};
	assign dataout[15:8] = treg[7:0];
	
	parameter IDLE = 2'b00;
	parameter LAT  = 2'b10;
	parameter CLK  = 2'b01;
	parameter SHFT = 2'b11;
	

	reg [2:0] bcnt;
	reg [11:0] clkcnt;

	wire ena;
	assign ena = ~|clkcnt;

	

	always @(posedge clk)
		if(en & (|clkcnt & |state))
			clkcnt <= clkcnt - 12'h1;
		else
			case (div) // synopsys full_case parallel_case
				2'b00: clkcnt <= 12'h0;   // 2
				2'b01: clkcnt <= 12'h1;   // 4
				2'b10: clkcnt <= 12'h3;   // 8
				2'b11: clkcnt <= 12'h7;   // 16
			endcase	


	reg delay;

	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			treg <= 8'h00;
			sclk <= 0;
			bcnt <= 3'h7;
			state <= IDLE;
			delay <= 0;
		end else begin
			case (state)
				IDLE: begin
					bcnt <= 3'h7;
					if (en)
						sclk <= 1;
					else
						sclk <= 0;
					delay <= 0;
					if (~wr_n) begin
						state <= LAT;
					end
				end
				
				LAT: begin
					delay <= 1;
					if (delay) begin
						treg <= datain[15:8];
						state <= CLK;
					end
				end
				
				CLK: begin
					if (ena) begin
						sclk <= ~ sclk;
						state <= SHFT;
					end
				end
				SHFT: begin
					if (ena) begin
						treg[7:1] <= treg[6:0];
						bcnt <= bcnt - 3'h1;
						
						if (~|bcnt) begin
							state <= IDLE;
						end else begin
							state <= CLK;
							sclk <= ~sclk;
						end
					end
				end
				default: state <= IDLE;

				endcase
		end
	end

endmodule
