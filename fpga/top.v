// Top module for Alcetronics M68K board FPGA
// Functional FPGA system
//
// 2012.04.10, ljalves, Created
//
//
`timescale 1ns / 1ps


//`define TEST_MAS3507D

module top(

	// system
	input wire rst_n,
	input wire int7_n,

	// input clocks
	input wire mclk,
	input wire cpuclk,
	input wire cpuEclk,
	input wire eth25clk,

	// enc24j60 interface
	input wire eth_int_n,
	input wire eth_miso,
	output wire eth_mosi,
	output wire eth_cs_n,
	output wire eth_sclk,

	// sdcard interface
	input wire sd_cd_n,
	input wire sd_miso,
	output wire sd_mosi,
	output wire sd_cs_n,
	output wire sd_busy_n,
	output wire sd_sclk,


	// adc interface
	input wire adc_miso,
	output wire adc_mosi,
	output wire adc_cs_n,
	output wire adc_sclk,


	// rtc interface
	output wire rtc_cs_n,
	output wire rtc_wr_n,
	output wire rtc_rd_n,
	output wire rtc_as,
	input wire rtc_int_n,
	inout wire [7:0] rtc_ad,

	
	// ftdi interface
	input wire ftdi_txe,
	input wire ftdi_rxf,
	

	// flash interface
	input wire flash_busy_n,


	// cpu interface
	input wire [2:0] cpu_fc,
	input wire [23:1] cpu_addrbus,
	inout wire [15:0] cpu_databus,
	output wire [2:0] ipl_n,
	output wire berr_n,
	output wire dtack_n,
	input wire as_n,
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
	input wire fpga_cs_n,
	output reg fpga_inctrl_n,
	output wire intr_cycle_n,
	
	input wire [11:2] cpld_aux,
	


	// I2C interface
	inout wire sda,
	inout wire sck,
	
	// UART interface
	input wire uart_rx,
	output wire uart_tx,

	// General Purpose PINS (available in the connector)
	// general purpose clock 
	output wire gp_clk,
	// general purpose IO1
	output wire [17:4] gpio1,
	// general purpose IO1 3.3V
	output wire [4:1] gpio1_3v3,
	// general purpose IO2
	output wire [15:0] gpio2,

   // red led (error led during fpga config)
	output red_led,

/*	`ifdef TEST_MAS3507D*/
	output wire mas_sclk,
	output wire mas_mosi,
	input wire mas_busy
/*	`endif */

	);


	/* unused signals */
	assign br_n = 1;
	assign bgack_n = 1;
	assign berr_n = 1;

	
	// fpga in control generation
	always @(posedge cpuclk or negedge rst_n)
		if (!rst_n)
			fpga_inctrl_n <= 1;
		else
			fpga_inctrl_n <= 0;
	



	// 1MHz clock generation using cpu E clock
	reg clk1;
	always @(posedge cpuEclk)
		clk1 <= ~clk1;
	
	// interrupt controller wires
	wire [15:0] intr_ctrl_in, intr_ctrl_out;
	wire [7:0] intr_vector;
	wire intr_dtack_n, intr_vpa_n;
		
	// timer0 wires
	wire [15:0] t0_preset, t0_value;
	/*wire [7:0] t0_ctrl_in, t0_ctrl_out;*/
	wire t0_en;
	wire t0_rst_int_n;
	wire t0_int_n;

	// timer1 wires
	/*wire [23:0] t1_preset, t1_value;
	wire [7:0] t1_ctrl_in, t1_ctrl_out;
	wire t1_rst_int_n;
	wire t1_int_n;*/

	// rtc wires
	wire [15:0] rtc_dout, rtc_din;
	wire rtc_rdh_n, rtc_rdl_n, rtc_wrh_n, rtc_wrl_n, rtc_dtack_n;
	
	// eth wires
	wire [15:0] eth_dout, eth_din;
	wire eth_wrh_n;

	// sdcard wires
	wire [15:0] sd_dout, sd_din;
	wire sd_wrh_n;
	wire sd_cd_rst_int_n;

	// adc wires
	wire [15:0] adc_dout, adc_din;
	wire adc_wrh_n;
	
	// UART wires
	wire [7:0] uart_din, uart_dout;
	wire [7:0] uart_ctrlin, uart_ctrlout;
	wire uart_wrh_n, uart_rdh_n;
	wire uart_int_n;

	// I2C wires
	wire [7:0] i2c_din, i2c_dout;
	wire [7:0] i2c_ctrlin, i2c_ctrlout;
	wire i2c_wrh_n, i2c_wrl_n, i2c_rdh_n;
	wire i2c_int_n;


	// MAS3507D wires
	`ifdef TEST_MAS3507D
	wire [15:0] mas_dout, mas_din;
	wire mas_wrh_n;
	`endif

	/* Peripheral control register */
	wire [7:0] pcr_ctrl;
	assign t0_en = pcr_ctrl[0];
	assign red_led = ~pcr_ctrl[7];
	
	bus_ctrl I0_bus_ctrl(
		//.t(gp_clk),

		.clk(cpuclk),
		.sysclk(mclk),
		.rst_n(rst_n),
		.rdl_n(rdl_n), .rdh_n(rdh_n),
		.wrl_n(wrl_n), .wrh_n(wrh_n),
		.as_n(as_n),
		.fpga_cs_n(fpga_cs_n),
		.cpu_addrbus(cpu_addrbus),
		.cpu_databus(cpu_databus),
		.cpu_fc(cpu_fc),
		
		.vpa_n(vpa_n),
		.dtack_n(dtack_n),
		
		.intr_cycle_n(intr_cycle_n),
		.intr_vector(intr_vector),
		.intr_ctrl_in(intr_ctrl_in),
		.intr_ctrl_out(intr_ctrl_out),
		
		.intr_vpa_n(intr_vpa_n),
		.intr_dtack_n(intr_dtack_n),
		
		.pcr_ctrl(pcr_ctrl),

		// timer0
		.timer0_preset(t0_preset),
		.timer0_value(t0_value),
		/*.timer0_ctrl_in(t0_ctrl_in),
		.timer0_ctrl_out(t0_ctrl_out),*/
		.timer0_rst_int_n(t0_rst_int_n),
		
		// timer1
		/*.timer1_preset(t1_preset),
		.timer1_value(t1_value),
		.timer1_ctrl_in(t1_ctrl_in),
		.timer1_ctrl_out(t1_ctrl_out),
		.timer1_rst_int_n(t1_rst_int_n),*/
		
		// DS12887 RTC
		.rtc_datain(rtc_din),
		.rtc_dataout(rtc_dout),
		.rtc_rdh_n(rtc_rdh_n),
		.rtc_rdl_n(rtc_rdl_n),
		.rtc_wrh_n(rtc_wrh_n),
		.rtc_wrl_n(rtc_wrl_n),
		.rtc_dtack_n(rtc_dtack_n),

		
		// ENC28J60 spi
		.eth_datain(eth_din),
		.eth_dataout(eth_dout),
		.eth_wrh_n(eth_wrh_n),

		// SDCARD spi
		.sd_datain(sd_din),
		.sd_dataout(sd_dout),
		.sd_wrh_n(sd_wrh_n),
		.sd_cd_rst_int_n(sd_cd_rst_int_n),
		.sd_cd_n(sd_cd_n),

		// ADC spi
		.adc_datain(adc_din),
		.adc_dataout(adc_dout),
		.adc_wrh_n(adc_wrh_n),
		
		// UART controller
		.uart_datain(uart_din),
		.uart_dataout(uart_dout),
		.uart_ctrlin(uart_ctrlin),
		.uart_ctrlout(uart_ctrlout),
		.uart_wrh_n(uart_wrh_n),
		.uart_rdh_n(uart_rdh_n),
		
		// I2C controller
		.i2c_datain(i2c_din),
		.i2c_dataout(i2c_dout),
		.i2c_ctrlin(i2c_ctrlin),
		.i2c_ctrlout(i2c_ctrlout),
		.i2c_wrh_n(i2c_wrh_n),
		.i2c_wrl_n(i2c_wrl_n),
		.i2c_rdh_n(i2c_rdh_n)

		`ifdef TEST_MAS3507D
		,.mas_datain(mas_din),
		.mas_dataout(mas_dout),
		.mas_wrh_n(mas_wrh_n)
		`endif
		
	);

	intr_ctrl I0_intr_ctrl(
		.clk(cpuclk),
		//.iclk(cpuclk),
		.rst_n(rst_n),
	
		.ipl_n(ipl_n),
		//.cpu_addrbus(cpu_addrbus[3:1]),
		.dtack_n(intr_dtack_n),
		.vpa_n(intr_vpa_n),
		
		.intr_vector(intr_vector),
		.intr_cycle_n(intr_cycle_n),
		
		.ctrl_in(intr_ctrl_in),
		.ctrl_out(intr_ctrl_out),
		
		.int7_n(int7_n),
		.timer0_int_n(t0_int_n),
		//.timer1_int_n(t1_int_n),
		.rtc_int_n(rtc_int_n),
		.eth_int_n(eth_int_n),

		.ftdi_rxf(ftdi_rxf),
		.ftdi_txe(ftdi_txe),
`ifdef TEST_MAS3507D
		.mas_int(mas_busy),
`endif		
		.uart_int_n(uart_int_n),

		.sd_cd_n(sd_cd_n),
		.sd_cd_rst_int_n(sd_cd_rst_int_n)
	);

	
	// general purpose timer0
	gp_timer I0_gp_timer(
		.clk(cpuclk),
		.tclk(clk1),
		.rst_n(rst_n),

		// from bus controller
		.preset(t0_preset),
		.value(t0_value),
		/*.ctrl_in(t0_ctrl_in),
		.ctrl_out(t0_ctrl_out),*/
		.en(t0_en),
		.rst_int_n(t0_rst_int_n),
		
		.int_n(t0_int_n)
	);

	// general purpose timer1
	/*gp_timer I1_gp_timer(
		.clk(cpuclk),
		.tclk(clk1),
		.rst_n(rst_n),
		
		// from bus controller
		.preset(t1_preset),
		.value(t1_value),
		.ctrl_in(t1_ctrl_in),
		.ctrl_out(t1_ctrl_out),
		.rst_int_n(t1_rst_int_n),
		
		.int_n(t1_int_n)
	);*/

	// DS12887 RTC
	rtc_ctrl I0_rtc_ctrl(
		.clk(cpuclk),
		.rst_n(rst_n),
	
		.cpu_addrbus(cpu_addrbus[6:1]),
		// from bus controller
		.rtc_datain(rtc_din),
		.rtc_dataout(rtc_dout),
		.rtc_rdh_n(rtc_rdh_n),
		.rtc_rdl_n(rtc_rdl_n),
		.rtc_wrh_n(rtc_wrh_n),
		.rtc_wrl_n(rtc_wrl_n),
		.rtc_dtack_n(rtc_dtack_n),
	
		// rtc interface
		.ad(rtc_ad),
		.rd_n(rtc_rd_n),
		.wr_n(rtc_wr_n),
		.cs_n(rtc_cs_n),
		.as(rtc_as)
	);

	spi_ctrl I0_enc28j60(
		.clk(mclk),
		.rst_n(rst_n),
	
		// cpu bus interface
		.spi_datain(eth_din),
		.spi_dataout(eth_dout),
		.spi_wrh_n(eth_wrh_n),

		// spi physical interface
		.miso(eth_miso),
		.mosi(eth_mosi),
		.cs_n(eth_cs_n),
		.sclk(eth_sclk)
	);

	spi_ctrl I0_sdcard(
		.clk(mclk),
		.rst_n(rst_n),
	
		// cpu bus interface
		.spi_datain(sd_din),
		.spi_dataout(sd_dout),
		.spi_wrh_n(sd_wrh_n),

		// spi physical interface
		.miso(sd_miso),
		.mosi(sd_mosi),
		.cs_n(sd_cs_n),
		.sclk(sd_sclk)
	);

	spi_ctrl I0_adc(
		.clk(mclk),
		.rst_n(rst_n),
	
		// cpu bus interface
		.spi_datain(adc_din),
		.spi_dataout(adc_dout),
		.spi_wrh_n(adc_wrh_n),

		// spi physical interface
		.miso(adc_miso),
		.mosi(adc_mosi),
		.cs_n(adc_cs_n),
		.sclk(adc_sclk)
	);

	uart_ctrl I0_uart(
		.sysclk(mclk),
		.clk(cpuclk),
		.rst_n(rst_n),
		
		.tx_data(uart_din),
		.rx_data(uart_dout),
		
		.ctrl_in(uart_ctrlin),
		.ctrl_out(uart_ctrlout),
		
		.data_wrh_n(uart_wrh_n),
		.data_rdh_n(uart_rdh_n),
		
		.rx(uart_rx),
		.tx(uart_tx),
		
		.uart_int_n(uart_int_n)

	);



	i2c_ctrl I0_i2c(
		.sysclk(mclk),
		.clk(cpuclk),
		.rst_n(rst_n),
		
		.datain(i2c_din),
		.dataout(i2c_dout),
		
		.ctrl_in(i2c_ctrlin),
		.ctrl_out(i2c_ctrlout),
		
		.data_wrh_n(i2c_wrh_n),
		.data_wrl_n(i2c_wrl_n),
		.data_rdh_n(i2c_rdh_n),
		
		.sda(sda),
		.sck(sck),
		
		.i2c_int_n(i2c_int_n)

	);


	`ifdef TEST_MAS3507D
	mas_ctrl I0_mas(
		.clk(mclk),
		.rst_n(rst_n),
	
		// cpu bus interface
		.datain(mas_din),
		.dataout(mas_dout),
		.wr_n(mas_wrh_n),

		// mas physical interface
		.mosi(mas_mosi),
		.busy(mas_busy),
		.sclk(mas_sclk)
	);
	`endif


	
	// SD card busy LED tied to busy status bit
	assign sd_busy_n = sd_cs_n; //uart_int_n;

	/*assign gp_clk = sd_sclk;
	assign gpio1[4] = sd_miso;
	assign gpio1[5] = sd_mosi;
	assign gpio1[6] = sd_cs_n;*/
	
	/*assign gpio1[1] = rtc_rdh_n;
	assign gpio1[2] = rtc_dtack_n;*/
	//assign gpio1[2] = t0_int_n;
	/*assign gpio1[8] = uart_rdh_n;
	assign gpio1[4] = uart_rdl_n;
	assign gpio1[6] = uart_int_n;*/

	//assign gpio1[4] = ovr;

	// debug
	//assign gp_clk = clk1;
	
endmodule
