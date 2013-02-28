`timescale 1ns / 1ps

module intr_ctrl(
	// system
	input wire clk,
//	input wire iclk,
	input wire rst_n,
	
	// cpu signals
	output reg [2:0] ipl_n,
	//input wire [3:1] cpu_addrbus,
	output reg dtack_n,
	output reg vpa_n,
	
	output wire [7:0] intr_vector,

	input wire intr_cycle_n,

	input wire [15:0] ctrl_in,
	output wire [15:0] ctrl_out,

	// interrupt sources
	input wire int7_n,
	input wire timer0_int_n,
	//input wire timer1_int_n,
	input wire rtc_int_n,
	input wire eth_int_n,

	`ifdef TEST_MAS3507D
	input wire mas_int,
	`endif

	// for ftdi interrupt generator
	input wire ftdi_rxf,
	input wire ftdi_txe,
	
	input wire uart_int_n,

	// SD card insert/remove int
	input wire sd_cd_n,
	input wire sd_cd_rst_int_n

);

	// loop back control register
	assign ctrl_out = ctrl_in;



   /*******************************************/
	/* SD card insertion/removal edge detector */
	reg sd_cd_1, sd_cd_2; //, sd_cd_3;
	always @(posedge clk) begin
		sd_cd_1 <= ~sd_cd_n;
		sd_cd_2 <= sd_cd_1;
		//sd_cd_3 <= sd_cd_2;
	end
	//assign sd_cd = (sd_cd_2 & ~sd_cd_3) | (~sd_cd_2 & sd_cd_3);
	assign sd_cd = (sd_cd_1 & ~sd_cd_2) | (~sd_cd_1 & sd_cd_2);

	reg sd_cd_int_n;
	/* SD card interrupt generator */
	always @(posedge clk or negedge rst_n)
		if (~rst_n) begin
			sd_cd_int_n <= 1;
		end else begin
			if (~sd_cd_rst_int_n)
				sd_cd_int_n <= 1;
			else if (sd_cd)
				sd_cd_int_n <= 0;
		end
	wire sd_cd_int_n_e;

	assign sd_cd_ien = ctrl_in[6];
	assign sd_cd_int_n_e = ~(~sd_cd_int_n & sd_cd_ien);
   /*******************************************/

	
   /*******************************************/
	/* ftdi interrupt generator                */
	assign ftdi_ien  = ctrl_in[0];
	assign ftdi_rxie = ctrl_in[1];
	assign ftdi_txie = ctrl_in[2];
	assign ftdi_int_n = ~(ftdi_ien & ((~ftdi_rxf & ftdi_rxie) | (~ftdi_txe & ftdi_txie)));
   /*******************************************/
	

   /*******************************************/
	/* enc28j60                                */
	assign eth_ien   = ctrl_in[3];
	assign eth_int_n_e = ~(~eth_int_n & eth_ien);
   /*******************************************/


   /*******************************************/
	/* fpga simple uart                        */
	assign uart_ien  = ctrl_in[4];
	assign uart_int_n_e = ~(~uart_int_n & uart_ien);
   /*******************************************/
	

   /*******************************************/
	/* MAS3507D                                */
	`ifdef TEST_MAS3507D
	assign mas_ien = ctrl_in[5];
	assign mas_int_n_e = ~(mas_int & mas_ien);
	`endif
   /*******************************************/



	/* interuupt level assign */

	wire [7:1] int_level;

	assign int_level[1] = ~sd_cd_int_n_e;//~timer1_int_n;
	assign int_level[2] = 0;
	assign int_level[3] = ~ftdi_int_n;
	assign int_level[4] = ~uart_int_n_e;
	assign int_level[5] = ~eth_int_n_e;
	assign int_level[6] = ~timer0_int_n | ~rtc_int_n
`ifdef TEST_MAS3507D
	| ~mas_int_n_e
`endif
;
	assign int_level[7] = ~int7_n;
	
	
	reg [2:0] ipl_n_r;
	
	// priority encoder
	always @(int_level)
		if (int_level[7])
			// int7
			ipl_n_r = 3'b000;
		else if (int_level[6])
			// int6
			ipl_n_r = 3'b001;
		else if (int_level[5])
			// int5
			ipl_n_r = 3'b010;
		else if (int_level[4])
			// int4
			ipl_n_r = 3'b011;
		else if (int_level[3])
			// int3
			ipl_n_r = 3'b100;
		else if (int_level[2])
			// int2
			ipl_n_r = 3'b101;
		else if (int_level[1])
			// int1
			ipl_n_r = 3'b110;
		else
			// no int
			ipl_n_r = 3'b111;

			
	// ipl_n sync'er
	always @(negedge clk or negedge rst_n)
		if (!rst_n)
			ipl_n <= 3'b111;
		else
			ipl_n <= ipl_n_r;
			

	// interrupt table (priority ordered)
	// vector = 00 will trigger autovector
	assign intr_vector = ~int7_n       ? 8'h00 : (
						 ~timer0_int_n ? 8'h40 : (
`ifdef TEST_MAS3507D							
						 ~mas_int_n_e  ? 8'h53 : (
`endif
						 ~rtc_int_n    ? 8'h50 : (
						 ~eth_int_n_e  ? 8'h51 : (
						 ~uart_int_n_e ? 8'h52 : (
						 ~ftdi_int_n   ? 8'h44 : (
						 ~sd_cd_int_n_e? 8'h42 : /*(
						 ~timer1_int_n ? 8'h41 : */
						 8'h00 ))))
`ifdef TEST_MAS3507D						 
						 )
`endif
						 )); //);

	parameter IDLE = 2'b00;
	parameter AVEC_INT = 2'b01;
	parameter VEC_INT = 2'b10;
	reg [1:0] int_state, n_int_state;

			
	// next int_state logic
	always @(*) begin : FSM_COMBO
		//n_int_state = 2'b00;
		case (int_state)
			IDLE: begin
				if (~intr_cycle_n)
					if (intr_vector == 8'h00)
						n_int_state = AVEC_INT;
					else
						n_int_state = VEC_INT;
				else
					n_int_state = IDLE;
			end
			AVEC_INT: begin
				if (intr_cycle_n)
					n_int_state = IDLE;
				else
					n_int_state = AVEC_INT;
			end
			VEC_INT: begin
				if (intr_cycle_n)
					n_int_state = IDLE;
				else
					n_int_state = VEC_INT;
			end
			default:
				n_int_state = IDLE;
		endcase
	end
	

	// int_state outputs
	always @(negedge clk or negedge rst_n)
		if (!rst_n) begin
			// base vector
			dtack_n <= 1;
			vpa_n <= 1;
			int_state <= IDLE;
		end else begin
			int_state <= n_int_state;
			case (int_state)
				IDLE: begin
					dtack_n <= 1;
					vpa_n <= 1;
				end
				VEC_INT: begin
					dtack_n <= 0;
				end
				AVEC_INT: begin
					vpa_n <= 0;
				end
				
			endcase
		
		end
		
		
endmodule
