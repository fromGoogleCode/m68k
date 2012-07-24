`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:35:59 03/25/2012 
// Design Name: 
// Module Name:    top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
	input wire mrst_n,
	output reg sysrst_n,
	output reg cpurst,
	
	
	input wire sysclk,
	output wire fpgaclk,
	output reg cpuclk,
	

	output wire rd_n,
	output wire rdl_n,
	output wire rdh_n,

	output wire wr_n,
	output wire wrl_n,
	output wire wrh_n,
	
	output wire [1:0] aux_cs_n,
	output wire [3:0] rom_cs_n,
	output wire [7:0] ram_cs_n,
	output wire fpga_cs_n,

	
	input wire [23:20] addrbus_h,
	input wire [8:1] addrbus_l,


	inout wire [7:0] cpu_databus,
	
	output wire fpga_pgm_n,

	
	input wire rw,
	input wire lds_n,
	input wire uds_n,
	input wire as_n,
	
	input wire ftdi_rxf,
	input wire ftdi_txe,
	
	output wire ftdi_wr_n,
	output wire ftdi_rd_n,
	
	input wire fpga_busy_n,
	
	output wire [9:2] aux,
	
	input wire fpga_inctrl_n,
	input wire intr_cycle_n,
	
	input wire fpga_dtack_n,
	output wire dtack_n
   );


	
	
	wire as_n_r;
	assign as_n_r = ~intr_cycle_n ? 1'b1 : as_n;
	

	/* Clock generation:
	cpuclk = 1/2 master clock
	fpgaclk = master clock */

	assign fpgaclk = sysclk;

	always @(posedge sysclk) begin
		cpuclk <= ~cpuclk;
	end


	/* reset with debounce */
	reg [16:0] delay;
	wire [16:0] nDelay;
	assign nDelay = delay + 17'h1;

	always @(posedge sysclk) begin
		if (!mrst_n) begin
			cpurst <= 1;
			sysrst_n <= 0;
			delay <= 17'h0001;
		end else begin
			if (delay == 17'h0) begin
				cpurst <= 0;
				sysrst_n <= 1;
			end else begin
				cpurst <= 1;
				sysrst_n <= 0;
				delay <= nDelay;
			end
		end
	end

	
	/* Address decoding */
	reg boot;

	/* ram */
	assign ram_cs_n[0] = boot ? 1'h1 : ~(~as_n_r & (addrbus_h[23:20] == 4'h0));
	assign ram_cs_n[1] = ~(~as_n_r & (addrbus_h[23:20] == 4'h1));
	assign ram_cs_n[2] = ~(~as_n_r & (addrbus_h[23:20] == 4'h2));
	assign ram_cs_n[3] = ~(~as_n_r & (addrbus_h[23:20] == 4'h3));
	assign ram_cs_n[4] = ~(~as_n_r & (addrbus_h[23:20] == 4'h4));
	assign ram_cs_n[5] = ~(~as_n_r & (addrbus_h[23:20] == 4'h5));
	assign ram_cs_n[6] = ~(~as_n_r & (addrbus_h[23:20] == 4'h6));
	assign ram_cs_n[7] = ~(~as_n_r & (addrbus_h[23:20] == 4'h7));

	/* rom */
	assign rom_cs_n[0] = boot ? as_n_r : ~(~as_n_r & (addrbus_h[23:20] == 4'h8));
	assign rom_cs_n[1] = ~(~as_n_r & (addrbus_h[23:20] == 4'h9));
	assign rom_cs_n[2] = ~(~as_n_r & (addrbus_h[23:20] == 4'hA));
	assign rom_cs_n[3] = ~(~as_n_r & (addrbus_h[23:20] == 4'hB));


	/* aux */
	assign aux_cs_n[0] = ~(~as_n_r & (addrbus_h[23:20] == 4'hC));
	assign aux_cs_n[1] = ~(~as_n_r & (addrbus_h[23:20] == 4'hD));

	/* ftdi */
	wire cpld_ftdi_cs;
	assign cpld_ftdi_cs = ~as_n_r & (addrbus_h[23:20] == 4'hE);

	/* fpga */
	assign fpga_cs_n = ~(~as_n_r & (addrbus_h[23:20] == 4'hF));


	/* boot module */
	reg [1:0] boot_cnt;
	always @(posedge as_n_r or negedge mrst_n) begin
		if (!mrst_n) begin
			boot <= 1;
			boot_cnt <= 2'h0;
		end else begin		
			if (boot_cnt == 2'h3) begin
				boot <= 0;
			end else begin
				boot_cnt <= boot_cnt + 2'h1;
			end
		end
	end



	/* read / write */
	assign rdl_n = ~(~lds_n & rw);
	assign rdh_n = ~(~uds_n & rw);
	assign rd_n  = ~(~rdl_n | ~rdh_n);

	assign wrl_n = ~(~lds_n & ~rw);
	assign wrh_n = ~(~uds_n & ~rw);
	assign wr_n  = ~(~wrl_n | ~wrh_n);



	/* ftdi & cpld control */
	
	wire ftdi_data_cs, ftdi_stat_cs, cpld_ctrl_cs;
	assign ftdi_data_cs = cpld_ftdi_cs & (addrbus_l[8:1] == 8'h00);
	assign ftdi_stat_cs = cpld_ftdi_cs & (addrbus_l[8:1] == 8'h01);
	assign cpld_ctrl_cs = cpld_ftdi_cs & (addrbus_l[8:1] == 8'h02);
	
	assign ftdi_rd_n = ~(~rdh_n & ftdi_data_cs);
	assign ftdi_wr_n = (~wrh_n & ftdi_data_cs);
	
	
	//wire rd_ftdi_data, wr_cpld_data;
	wire rd_ftdi_stat;
	wire rd_cpld_ctrl, wr_cpld_ctrl;

	assign rd_ftdi_stat = ftdi_stat_cs & ~rdh_n;
	assign rd_cpld_ctrl = cpld_ctrl_cs & ~rdh_n;
	assign wr_cpld_ctrl = cpld_ctrl_cs & ~wrh_n;
	
	
	wire rd_cpld;
	assign rd_cpld = rd_ftdi_stat | rd_cpld_ctrl;
	

	
	reg [7:0] cpu_databus_out;
	assign cpu_databus[7:0] = rd_cpld ? cpu_databus_out : 8'hzz;
	
	reg [6:0] cpld_ctrl_reg;
	assign fpga_pgm_n = cpld_ctrl_reg[0];
	

	reg as_n_d0, as_n_d;
	always @(posedge cpuclk or negedge mrst_n)
		if (!mrst_n) begin
			as_n_d0 <= 1;
			as_n_d  <= 1;
		end else begin
			as_n_d0 <= as_n;
			as_n_d  <= as_n_d0;
		end


	always @(negedge as_n_d or negedge mrst_n)
		if (!mrst_n) begin
			cpld_ctrl_reg[6:0] <= 7'h01;
			cpu_databus_out[7:0] <= 8'h00;
		end else begin
			if (wr_cpld_ctrl)
				cpld_ctrl_reg[6:0] <= cpu_databus[6:0];
			else if (rd_cpld_ctrl)
				cpu_databus_out[7:0] <= {fpga_busy_n, cpld_ctrl_reg[6:0]};
			else if (rd_ftdi_stat)
				cpu_databus_out[7:0] <= {6'b000000, ftdi_txe, ftdi_rxf};
		end


	reg dtack_ftdi;
   // dtack grounded while fpga doesnt assume control
	assign dtack_n = ftdi_data_cs ? dtack_ftdi : (
						 ~fpga_inctrl_n ? fpga_dtack_n : 0);
		

	reg [1:0] ws_cnt;
	always @(posedge cpuclk or posedge as_n)
		if (as_n) begin
			dtack_ftdi <= 1;
			ws_cnt <= 2'h0;
		end else
			if (ws_cnt == 2'h2)
				dtack_ftdi <= 0;
			else
				ws_cnt <= ws_cnt + 2'h1;
			

endmodule
