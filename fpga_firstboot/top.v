// Top module for Alcetronics M68K board FPGA
// Initial FLASH loader
//
// Loading process:
// 1) CPLD programs FPGA with bitstream from FTDI245
// 2) FPGA becomes busmaster
// 3) FPGA read from FTDI245 and write/verify FLASH
//
// 2012.03.28, ljalves, Created
//
//

module top(

	// system
	input wire rst_n,
	input wire int7_n,

	// input clocks
	input wire mclk,
	input wire cpuclk,
	input wire cpuEclk,
	input wire eth25clk,

	// output clocks
	output wire eth_sclk,
	output wire adc_sclk,
	output wire sd_sclk,


	// enc24j60 interface
	input wire eth_int_n,
	input wire eth_miso,
	output wire eth_mosi,
	output wire eth_cs_n,


	// sdcard interface
	input wire sd_cd_n,
	input wire sd_miso,
	output wire sd_mosi,
	output wire sd_cs_n,
	output reg sd_busy_n,


	// adc interface
	input wire adc_miso,
	output wire adc_mosi,
	output wire adc_cs_n,
		

	// rtc interface
	output wire rtc_cs_n,
	output wire rtc_wr_n,
	output wire rtc_rd_n,
	output wire rtc_as_n,
	input wire rtc_int_n,
	inout wire [7:0] rtc_ad,
	
	
	// ftdi interface
	input wire ftdi_txe,
	input wire ftdi_rxf,
	

	// flash interface
	input wire flash_busy_n,


	// cpu interface
	input wire [2:0] cpu_fc,
	inout wire [23:1] cpu_addrbus,
	inout wire [15:0] cpu_databus,
	output wire [2:0] ipl_n,
	output wire berr_n,
	output wire dtack_n,
	inout wire as_n,
	input wire wrh_n,
	input wire wrl_n,
	input wire rdh_n,
	input wire rdl_n,
	input wire vma_n,
	output wire vpa_n,
	output wire br_n,
	input wire bg_n,
	output wire bgack_n,
	
	
	
	// cpld interface
	input wire fpga_cs,
	
	input wire [11:5] cpld_aux,
	
	
	output reg cpu_inctrl;
	
	output wire fpga_inctrl,
	output reg lds,
	output reg uds,
	output reg rw,

	/*
	cpld_aux[0]=fpga_inctrl
	cpld_aux[1]=lds
	cpld_aux[2]=uds
	cpld_aux[3]=rw
	*/


	// I2C interface
	inout wire sda,
	output wire sck,
	


	// General Purpose PINS (available in the connector)
	// general purpose clock 
	output wire gp_clk,
	// general purpose IO1
	output wire [17:0] gpio1,
	// general purpose IO1 3.3V
	output wire [4:0] gpio1_3v3,
	// general purpose IO2
	output wire [15:0] gpio2
	);
	
	reg [23:1] cpu_addrbus_out;
	assign cpu_addrbus = cpu_inctrl ? cpu_addrbus_out : 23'hzzzzzz;
	
	reg as_n_r;
	assign as_n = cpu_inctrl ? as_n_r : 1'hz;
	
	
	reg rw_cpu_inctrl;
	reg [15:0] c_data_out;
	
	reg [15:0] dataout, datain;
	assign cpu_databus = rw_cpu_inctrl ? c_data_out : (~rw ? dataout : 16'hzzzz);

	// im alive blinking led
	/*reg [23:0] cnt;
	always @(posedge mclk or negedge rst_n) begin
		if (!rst_n)
			cnt <= 24'h0;
		else begin
			cnt <= cnt + 24'h1;
			if (cnt == 24'h0)
				sd_busy_n <= ~sd_busy_n;
		end
	end*/

	assign fpga_inctrl = 0;



	reg wr_ftdi, rd_ftdi;
	reg wr_ram, rd_ram;
	
	reg clk8;
	always @(posedge cpuclk)
		clk8 <= ~clk8;
	reg clk4;
	always @(posedge clk8)
		clk4 <= ~clk4;

	reg clk2;
	always @(posedge clk4)
		clk2 <= ~clk2;



	reg [23:1] A0;
	reg [15:0] R0;
	reg [7:0] F0;



	reg [3:0] bus_ST, bus_nST;
	
	wire bus_busy;
	assign bus_busy = (bus_ST != 4'h0);
	
	
	
	always @(posedge cpuclk) begin
		if (!cpu_inctrl & (cpu_addrbus[23:1] == 23'h780000) & !rdl_n) begin
			c_data_out[7:0] <= {6'b000000, ftdi_txe, ftdi_rxf};
			rw_cpu_inctrl <= 1;
		end else	
			rw_cpu_inctrl <= 0;
			
	end
	
	
	
	always @(*)
		case (bus_ST)
			4'h0: begin
				if (rd_ftdi)
					bus_nST = 4'h1;
				else if (wr_ftdi)
					bus_nST = 4'h2;
				else if (rd_ram)
					bus_nST = 4'h3;
				else if (wr_ram)
					bus_nST = 4'h4;
				else
					bus_nST = 4'h0;
			end
			4'h1: bus_nST = 4'h7;
			4'h2: bus_nST = 4'h9;
			4'h3: bus_nST = 4'h7;
			4'h4: bus_nST = 4'h9;
			4'h7: bus_nST = 4'h8;
			4'h8: bus_nST = 4'h0;
			4'h9: bus_nST = 4'hA;
			4'hA: bus_nST = 4'h0;
	
			default: bus_nST = 4'h0;
		endcase
	
	
	
	
	
	always @(negedge clk2 or negedge int7_n)
		if (!int7_n) begin
			as_n_r <= 1;
			uds <= 1;
			lds <= 1;
			rw <= 1;
			cpu_addrbus_out <= 23'h7FFFFF;
			bus_ST <= 4'h0;
		end else begin
			bus_ST <= bus_nST;
			case (bus_ST)
				4'h0: begin
					// IDLE
					as_n_r <= 1;
					uds <= 1;
					lds <= 1;
					rw <= 1;					
				end
				
				4'h1, 4'h2: begin
					cpu_addrbus_out <= 23'h780000;
					dataout[15:8] <= F0;
				end
				4'h3, 4'h4: begin
					cpu_addrbus_out <= A0;
					dataout[15:0] <= R0[15:0];
				end
				
				4'h7: begin
					// read cycle
					as_n_r <= 0;
					uds <= 0;
					lds <= 0;
				end
				4'h8: begin
					// read cycle
					datain[15:0] <= cpu_databus[15:0];
					//bus_ST <= 4'h0;
				end

				4'h9: begin
					// write cycle
					as_n_r <= 0;
					uds <= 0;
					lds <= 0;
					rw <= 0;
					//bus_ST <= 4'hA;
				end
				4'hA: begin
					// write cycle
					uds <= 1;
					lds <= 1;
					//bus_ST <= 4'h0;
				end
				
			endcase
		
		end
	
	
	
	
	
	
	
	
	

	// read bytes from ftdi245

	
	
	//always @(posedge)
	

	reg [2:0] cmd_ST, cmd_nST;
	reg [4:0] cmd2_ST, cmd2_nST;

	reg cmd, cmd_r, busy;
	
	always @(*) begin
		case (cmd_ST)
			3'h0:
				if (!ftdi_rxf & !busy)
					cmd_nST = 3'h1;
				else
					cmd_nST = 3'h0;
			3'h1: cmd_nST = 3'h2;
			3'h2: 
				if (bus_busy)
					cmd_nST = 3'h2;
				else
					cmd_nST = 3'h3;
			3'h3: cmd_nST = 3'h4;
			3'h4: cmd_nST = 3'h0;

			default: cmd_nST = 3'h0;
		endcase
	end			
	
	
	reg [7:0] b;
	
	always @(posedge clk2 or negedge int7_n)
		if (!int7_n) begin
			rd_ftdi <= 0;
			cmd <= 0;	
			cmd_ST <= 3'h0;
		end else begin
			cmd_ST <= cmd_nST;
			case (cmd_ST)
				3'h0: begin
					// IDLE
					//cmd <= 0;
					//rd_ftdi <= 0;
				end

				// char in buffer, read it
				3'h1: begin
					rd_ftdi <= 1;
				end
				3'h2: begin
					rd_ftdi <= 0;
				end
				3'h3: begin
					b <= datain[15:8];
					cmd <= 1;
				end
				3'h4: begin
					cmd <= 0;
				end
		
			endcase
		end




	always @(negedge clk2)
		cmd_r <= cmd;
/*
	
	always @(*)
		case (cmd2_ST)
			5'00:
				if (cmd_r & (datain[15:8] == 8'd65))
					cmd2_nST = 5'h01;
				else if (cmd_r & (datain[15:8] == 8'd66))
					cmd2_nST = 5'h10;
				else
					cmd2_nST = 5'h00;
			5'h01:
				*/
	
	always @(posedge clk2 or negedge int7_n)
		if (!int7_n) begin
			rd_ram <= 0;
			wr_ram <= 0;
			wr_ftdi <= 0;
			sd_busy_n <= 0;
			cmd2_ST <= 5'h0;
			busy <= 0;
			cpu_inctrl <= 1;
		end else begin
			case (cmd2_ST)
			
				5'h0: begin
					busy <= 0;

					// IDLE
					sd_busy_n <= 1;
					
					if (cmd_r)
						case (b)
							8'd65: cmd2_ST <= 5'h01;
							8'd66: cmd2_ST <= 5'h10;
							8'd67: cmd2_ST <= 5'h1F;
							//default: cmd2_ST <= 5'h0;
						endcase
					/*else
						cmd2_ST <= 5'h0;*/
					
					
					
				end
				
				// load to RAM
				5'h01: begin
					// 1 addr byte
					sd_busy_n <= 0;
					if (cmd_r) begin
						A0[23:16] <= datain[15:8];
						cmd2_ST <= 5'h2;
					end/* else
						cmd2_ST <= 5'h1;*/
				end
				5'h02: begin
					// 2 addr byte
					if (cmd_r) begin
						A0[15:8] <= datain[15:8];
						cmd2_ST <= 5'h3;
					end/* else
						cmd2_ST <= 5'h2;*/
				end
				5'h03: begin
					if (cmd_r) begin
						A0[7:1] <= datain[15:9];
						cmd2_ST <= 5'h4;
					end/* else
						cmd2_ST <= 5'h3;*/
				end
				5'h04: begin
					sd_busy_n <= 1;
					
					if (cmd_r) begin
						R0[15:8] <= datain[15:8];
						cmd2_ST <= 5'h5;
					end/* else
						cmd2_ST <= 5'h4;*/
				end
				5'h05: begin
					sd_busy_n <= 0;
					
					if (cmd_r) begin
						busy <= 1;

						R0[7:0] <= datain[15:8];
						cmd2_ST <= 5'h6;
					end/* else
						cmd2_ST <= 5'h5;*/
				end
				5'h06: begin
					// write
					wr_ram <= 1;
					cmd2_ST <= 5'h7;
				end
				5'h07: begin
					// write
					wr_ram <= 0;
					cmd2_ST <= 5'h8;
				end
				5'h08: begin
					// write
					if (!bus_busy) begin
						A0 <= A0 + 23'h1;
						cmd2_ST <= 5'h0;
					end/* else
						cmd2_ST <= 5'h8;*/
				end



				// read RAM
				5'h10: begin
					// 1 addr byte
					sd_busy_n <= 0;
					if (cmd_r) begin
						A0[23:16] <= datain[15:8];
						cmd2_ST <= 5'h11;
					end
				end
				5'h11: begin
					// 2 addr byte
					if (cmd_r) begin
						A0[15:8] <= datain[15:8];
						cmd2_ST <= 5'h12;
					end
				end
				5'h12: begin
					if (cmd_r) begin
						busy <= 1;

						A0[7:1] <= datain[15:9];
						cmd2_ST <= 5'h13;
					end
				end
				5'h13: begin
					sd_busy_n <= 1;
					// read word
					rd_ram <= 1;
					cmd2_ST <= 5'h14;
				end
				5'h14: begin
					rd_ram <= 0;
					if (!bus_busy)
						cmd2_ST <= 5'h15;
				end
				5'h15: begin
					// write
					F0[7:0] <= datain[15:8];
					wr_ftdi <= 1;
					cmd2_ST <= 5'h16;
				end
				5'h16: begin
					// write
					wr_ftdi <= 0;
					if (!bus_busy)
						cmd2_ST <= 5'h17;
				end
				5'h17: begin
					// write
					F0[7:0] <= datain[7:0];
					wr_ftdi <= 1;
					cmd2_ST <= 5'h18;
				end
				5'h18: begin
					wr_ftdi <= 0;
					if (!bus_busy)
						cmd2_ST <= 5'h19;
				end
				5'h19: begin
					A0 <= A0 + 23'h1;
					cmd2_ST <= 5'h0;
				end				

				5'h1F: begin
					cpu_inctrl <= 0;
					cmd2_ST <= 5'h1F;
				end				
			endcase
		end

	

endmodule
	