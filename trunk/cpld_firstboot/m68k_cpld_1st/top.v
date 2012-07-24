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
	input wire mrst,
	output reg sysrst,
	output reg cpurst,
	
	
	input wire sysclk,
	output wire fpgaclk,
	output reg cpuclk,
	

	output wire rd,
	output wire rdl,
	output wire rdh,

	output wire wr,
	output wire wrl,
	output wire wrh,
	
	output wire [1:0] aux_cs,
	output wire [3:0] rom_cs,
	output wire [7:0] ram_cs,
	output reg fpga_cs,

	
	input wire [23:20] addrbus_h,
	input wire [8:1] addrbus_l,


	input wire [7:0] databus,
	
	output reg fpga_pgm,

	
	input wire rw,
	input wire lds,
	input wire uds,
	input wire as,
	
	input wire ftdi_rxf,
	input wire ftdi_txe,
	
	output wire ftdi_wr,
	output wire ftdi_rd,
	
	input wire fpga_busy,
	
	
	output reg [9:5] aux,
	
	input wire cpu_inctrl,

	// fpga in control
	input wire fpga_inctrl,
	input wire uds2,
	input wire lds2,
	input wire rw2,
	
	input wire fpga_dtack,
	output wire dtack
   );

	
	assign dtack = 1'b0;


	/* Clock generation:
	cpuclk = 1/2 master clock
	fpgaclk = master clock */

	assign fpgaclk = sysclk;

	always @(posedge sysclk) begin
		cpuclk <= ~cpuclk;
	end

	reg clk8;
	always @(posedge cpuclk) begin
		clk8 <= ~clk8;
	end
	
	reg clk4;
	always @(posedge clk8) begin
		clk4 <= ~clk4;
	end


	reg [15:0] delay;
	wire [15:0] nDelay;
	assign nDelay = delay + 16'h1;

	/* reset */
	always @(posedge sysclk) begin
		if (!mrst) begin
			cpurst <= 1;
			sysrst <= 0;
			delay <= 16'h0001;
		end else begin
			if (!cpu_inctrl & (delay == 16'h0)) begin
				cpurst <= 0;
			end else begin
				cpurst <= 1;
				delay <= nDelay;
			end
			sysrst <= 1;
		end
	end

	
	
	
	// address decoding
	
	wire ftdi_cs;
	assign ftdi_cs = ~as & (addrbus_h == 4'hF);
	
	assign ram_cs[0] = ~(~as & (addrbus_h == 4'h0));
	assign ram_cs[1] = ~(~as & (addrbus_h == 4'h1));
	assign ram_cs[2] = ~(~as & (addrbus_h == 4'h2));
	assign ram_cs[3] = ~(~as & (addrbus_h == 4'h3));
	assign ram_cs[4] = ~(~as & (addrbus_h == 4'h4));
	assign ram_cs[5] = ~(~as & (addrbus_h == 4'h5));
	assign ram_cs[6] = ~(~as & (addrbus_h == 4'h6));
	assign ram_cs[7] = ~(~as & (addrbus_h == 4'h7));

	assign rom_cs[0] = ~(~as & (addrbus_h == 4'h8));
	assign rom_cs[1] = ~(~as & (addrbus_h == 4'h9));
	assign rom_cs[2] = ~(~as & (addrbus_h == 4'hA));
	assign rom_cs[3] = ~(~as & (addrbus_h == 4'hB));




	wire rd_ftdi_i, wr_ftdi_i;
	
	assign rd_ftdi_i = ~(~rdh & ftdi_cs);
	assign wr_ftdi_i = ~(~wrh & ftdi_cs);


	


	// load fpga FSM

	reg wr_fpga, rd_ftdi;
	
	wire wrh2, rdh2, rd2;
	wire wrl2, rdl2, wr2;
	
	assign wrh2 = ~(~uds2 & ~rw2);
	assign wrl2 = ~(~lds2 & ~rw2);
	assign rdh2 = ~(~uds2 & rw2);
	assign rdl2 = ~(~lds2 & rw2);
	assign rd2 = ~(~rdl2 & ~rdh2);
	assign wr2 = ~(~wrl2 & ~wrh2);

	wire cpu_wrh, cpu_rdh, cpu_rd;
	wire cpu_wrl, cpu_rdl, cpu_wr;

	assign cpu_wrh = ~(~uds & ~rw);
	assign cpu_wrl = ~(~lds & ~rw);
	assign cpu_rdh = ~(~uds & rw);
	assign cpu_rdl = ~(~lds & rw);
	assign cpu_rd = ~(~cpu_rdl | ~cpu_rdh);
	assign cpu_wr = ~(~cpu_wrl | ~cpu_wrh);
	
	/*assign wrh = ~fpga_inctrl ? wrh2 : wr_fpga;
	assign wrl = ~fpga_inctrl ? wrl2 : 1;
	assign rdh = ~fpga_inctrl ? rdh2 : 1;
	assign rdl = ~fpga_inctrl ? rdl2 : 1;
	assign wr = ~fpga_inctrl ? wr2 : 1;
	assign rd = ~fpga_inctrl ? rd2 : 1;*/
	
	assign wrh = ~cpu_inctrl ? cpu_wrh : (~fpga_inctrl ? wrh2 : wr_fpga);
	assign wrl = ~cpu_inctrl ? cpu_wrl : (~fpga_inctrl ? wrl2 : 1);
	assign rdh = ~cpu_inctrl ? cpu_rdh : (~fpga_inctrl ? rdh2 : 1);
	assign rdl = ~cpu_inctrl ? cpu_rdl : (~fpga_inctrl ? rdl2 : 1);
	assign wr = ~cpu_inctrl ? cpu_wr : (~fpga_inctrl ? wr2 : 1);
	assign rd = ~cpu_inctrl ? cpu_rd : (~fpga_inctrl ? rd2 : 1);
	
	
	
	assign ftdi_wr = ~fpga_inctrl ? wr_ftdi_i : 1;
	assign ftdi_rd = ~fpga_inctrl ? rd_ftdi_i : rd_ftdi;
	
	
	
	
	
	reg [1:0] STATE, nSTATE;

	always @(STATE) begin
		case (STATE)
			2'b00:
				if ((!ftdi_rxf) & (fpga_busy))
					nSTATE = 2'b01;
				else
					nSTATE = 2'b00;
			2'b01:
				nSTATE = 2'b10;
			2'b10:
				nSTATE = 2'b11;
			2'b11:
				nSTATE = 2'b00;
		endcase
	end
	

	always @(posedge clk4 or negedge mrst)
		if (!mrst)
			STATE <= 2'b00;
		else
			STATE <= nSTATE;


	always @(posedge clk4 or negedge mrst)
		if (!mrst) begin
			if (cpu_inctrl)
				fpga_pgm <= 0;
			fpga_cs <= 1;
			wr_fpga <= 1;
			rd_ftdi <= 1;
		end else begin
			if (cpu_inctrl)
				fpga_pgm <= 1;
			
			case (STATE)
				2'b00: begin
					// idle
				end
				2'b01: begin
					fpga_cs <= 0;
					wr_fpga <= 0;
					rd_ftdi <= 0;
				end
				
				2'b10: begin
					wr_fpga <= 1;
				end
				2'b11: begin
					fpga_cs <= 1;
					rd_ftdi <= 1;
				end
			endcase
		end
	
	
	

endmodule
