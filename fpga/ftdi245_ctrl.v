/*
   FTDI245 simple interrupt generator module
   Generates:
		RX interrupt when a character is ready to read.
		TX interrupt whenever TX FIFO is not full (ready to send).

   Author: ljalvs@gmail.com
   
   2012.05.15, ljalvs@gmail.com, Created.

*/

module ftdi245_ctrl(
	input wire clk,
	input wire rst_n,

	input wire [2:0] ctrl_in,
	//output wire [7:0] ctrl_out,
	
	input wire data_wrh_n,

	input wire rxf,
	input wire txe,
	
	// commmon interrupt
	output wire ftdi_int_n
	
	/*
	// separated interrupts
	output wire ftdi_rxint_n,
	output wire ftdi_txint_n
	*/
);

	// control byte:
	// [0,0,0,0,0,TXIE,RXIE,IEN]

	assign ien = ctrl_in[0];
	assign rxie = ctrl_in[1];
	assign txie = ctrl_in[2];

	assign ftdi_int_n = ~(ien & ((~rxf & rxie) | (~txe & txie)));
	
	/*
	assign ftdi_rxint_n = ~(ien & ~rxf & rxie);
	assign ftdi_txint_n = ~(ien & ~txe & txie);
	*/

endmodule
