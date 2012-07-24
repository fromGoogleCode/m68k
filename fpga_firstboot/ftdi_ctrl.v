// FTDI245 controller for Alcetronics M68K board FPGA
// Initial FLASH loader
//
// 2012.03.28, ljalves, Created
//
//

module ftdi245_ctrl(
	
	// system
	input wire rst,
	input wire clk,
	
	input wire txe,
	input wire rxf,
	
	