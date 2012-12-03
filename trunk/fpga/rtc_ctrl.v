`timescale 1ns / 1ps

/*
   RTC DS12887 controller module
   Author: ljalvs@gmail.com
   
   This module maps the memory of the RTC in
   the 68k address range.
   
   The mapping is continuous so Byte and Word
   operations are are allowed.
   
   2012.05.13, ljalvs@gmail.com, Created.

*/

module rtc_ctrl(
	input wire clk,
	input wire rst_n,
	
	// cpu bus interface
	input wire [6:1] cpu_addrbus,
	input wire [15:0] rtc_datain,
	output reg [15:0] rtc_dataout,
	input wire rtc_rdh_n,
	input wire rtc_rdl_n,
	input wire rtc_wrh_n,
	input wire rtc_wrl_n,
	
	output reg rtc_dtack_n,
	
	// rtc interface
	inout wire [7:0] ad,
	output reg rd_n,
	output reg wr_n,
	output reg cs_n,
	output reg as
);


	reg [7:0] ad_out;
	assign ad = rd_n ? ad_out : 8'hzz;
	
	wire A0;
	assign A0 = (~rtc_rdl_n | ~rtc_wrl_n);
	
	wire rtc_cs;
	assign rtc_cs = (~rtc_rdh_n | ~rtc_rdl_n | ~rtc_wrh_n | ~rtc_wrl_n);
	
	parameter IDLE  = 4'h0;
	parameter RD1B0 = 4'h1;
	parameter RD1B1 = 4'h2;
	parameter RD1B2 = 4'h3; //0011
	
	parameter RD2B0 = 4'h4;
	parameter RD2B1 = 4'h5;
	parameter RD2B2 = 4'h6; //0110
	parameter RD2B3 = 4'h7;
	parameter RD2B4 = 4'h8;
	parameter RD2B5 = 4'h9;
	
	parameter WR1B0 = 4'hA;
	parameter WR1B1 = 4'hB; //1011

	parameter WR2B0 = 4'hC;
	parameter WR2B1 = 4'hD; //1101
	parameter WR2B2 = 4'hE;
	parameter WR2B3 = 4'hF;
	
	
	reg [3:0] rtc_state /* synthesis syn_encoding="original" */;
	reg [3:0] n_rtc_state;
	
	// state machine state logic
	always @(*) begin
		case (rtc_state)
			IDLE: begin
				if ((~rtc_rdh_n & rtc_rdl_n) | (rtc_rdh_n & ~rtc_rdl_n))
					// byte read
					n_rtc_state = RD1B0;
				else if (~rtc_rdh_n & ~rtc_rdl_n)
					// word read
					n_rtc_state = RD2B0;
				else if ((~rtc_wrh_n & rtc_wrl_n) | (rtc_wrh_n & ~rtc_wrl_n))
					// byte write
					n_rtc_state = WR1B0;
				else if (~rtc_wrh_n & ~rtc_wrl_n)
				    // word write
					n_rtc_state = WR2B0;
				else
					// no-op
					n_rtc_state = IDLE;
			end
			
			// byte read
			RD1B0: n_rtc_state = RD1B1;				
			RD1B1: n_rtc_state = RD1B2;
			RD1B2: if (~rtc_cs)
					n_rtc_state = IDLE;
				else
					n_rtc_state = RD1B2;

			// word read
			RD2B0: n_rtc_state = RD2B1;
			RD2B1: n_rtc_state = RD2B2;
			RD2B2: n_rtc_state = RD2B3;
			RD2B3: n_rtc_state = RD2B4;
			RD2B4: n_rtc_state = RD2B5;
			RD2B5: if (~rtc_cs)
					n_rtc_state = IDLE;
				else
					n_rtc_state = RD2B5;
					
			// byte write
			WR1B0: n_rtc_state = WR1B1;
			WR1B1: if (~rtc_cs)
					n_rtc_state = IDLE;
				else
					n_rtc_state = WR1B1;

			// word write
			WR2B0: n_rtc_state = WR2B1;
			WR2B1: n_rtc_state = WR2B2;
			WR2B2: n_rtc_state = WR2B3;
			WR2B3: if (~rtc_cs)
					n_rtc_state = IDLE;
				else
					n_rtc_state = WR2B3;
			default: n_rtc_state = IDLE;
		endcase
	end	
	
	// state machine output logic
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			cs_n <= 1;
			rd_n <= 1;
			wr_n <= 1;
			as <= 0;
			ad_out <= 8'h00;
			rtc_dtack_n <= 1;
			rtc_dataout <= 16'h0000;
			rtc_state <= IDLE;
		end else begin
			rtc_state <= n_rtc_state;
			case (rtc_state)
				IDLE: begin
					as <= 0;
					cs_n <= 1;
					rd_n <= 1;
					wr_n <= 1;
					rtc_dtack_n <= 1;
				end
			
				RD1B0, WR1B0, RD2B0, WR2B0: begin
					as <= 1;
					cs_n <= 0;
					ad_out[7:0] <= {cpu_addrbus[6:1], A0};
				end
		
				RD1B1, RD2B1, RD2B4: begin
					as <= 0;
					rd_n <= 0;
				end
				
				RD1B2, RD2B2: begin
					rtc_dtack_n <= rtc_state[2]; // 0 if RD1B1; 1 if RD2B1
					if (~rtc_rdl_n)
						rtc_dataout[7:0] <= ad[7:0];
					else if (~rtc_rdh_n)
						rtc_dataout[15:8] <= ad[7:0];
				end
				
				// word read
				RD2B3: begin
					rd_n <= 1;
					as <= 1;
					ad_out[7:0] <= {cpu_addrbus[6:1], 1'b0};
				end

				RD2B5: begin
					//rd_n <= 1;
					rtc_dtack_n <= 0;
					rtc_dataout[15:8] <= ad[7:0];
				end

				
				// byte write
				WR1B1, WR2B1: begin
					as <= 0;
					wr_n <= 0;
					rtc_dtack_n <= rtc_state[2]; // 0 if WR1B1; 1 if WR2B1
					if (~rtc_wrl_n)
						ad_out[7:0] <= rtc_datain[7:0];
					else if (~rtc_wrh_n)
						ad_out[7:0] <= rtc_datain[15:8];
				end
				
				// word write
				WR2B2: begin
					as <= 1;
					wr_n <= 1;
					ad_out[7:0] <= {cpu_addrbus[6:1], 1'b0};
				end

				WR2B3: begin
					as <= 0;
					wr_n <= 0;
					rtc_dtack_n <= 0;
					ad_out[7:0] <= rtc_datain[15:8];
				end
				
			endcase
		end
	
	
endmodule
