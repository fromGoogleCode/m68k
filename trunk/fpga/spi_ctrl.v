`timescale 1ns / 1ps
/*
   SPI controller module
   Author: ljalvs@gmail.com
   
   Simple SPI controller

   2012.05.15, ljalvs@gmail.com, Created.

*/

module spi_ctrl(
	input wire clk,
	input wire rst_n,
	
	// cpu bus interface
	input wire [15:0] spi_datain,
	output wire [15:0] spi_dataout,
	input wire spi_wrh_n,

	// spi physical interface
	input wire miso,
	output wire mosi,
	output wire cs_n,
	output reg sclk
);


	reg [1:0] state;
	reg [7:0] treg;
	assign mosi = treg[7];


	// low byte = control
	// high byte = data

	wire en;
	wire [3:0] div;
	wire busy;
	assign busy = |state;
	
	assign div  = spi_datain[3:0];
	assign cs_n = ~spi_datain[4];
	assign en   = spi_datain[5];
	
	
	assign spi_dataout[7:0] = {busy, spi_datain[6:0]};
	assign spi_dataout[15:8] = treg[7:0];
	
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
			clkcnt <= clkcnt - 11'h1;
		else
			case (div) // synopsys full_case parallel_case
				4'b0000: clkcnt <= 12'h0;   // 2
				4'b0001: clkcnt <= 12'h1;   // 4
				4'b0010: clkcnt <= 12'h3;   // 8
				4'b0011: clkcnt <= 12'h7;   // 16
				4'b0100: clkcnt <= 12'hf;   // 32
				4'b0101: clkcnt <= 12'h1f;  // 64
				4'b0110: clkcnt <= 12'h3f;  // 128
				4'b0111: clkcnt <= 12'h7f;  // 256
				4'b1000: clkcnt <= 12'hff;  // 512
				4'b1001: clkcnt <= 12'h1ff; // 1024
				4'b1010: clkcnt <= 12'h3ff; // 2048
				4'b1011: clkcnt <= 12'h7ff; // 4096
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
					sclk <= 0;
					delay <= 0;
					if (~spi_wrh_n) begin
						state <= LAT;
					end
				end
				
				LAT: begin
					delay <= 1;
					if (delay) begin
						treg <= spi_datain[15:8];
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
						treg <= {treg[6:0], miso};
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
