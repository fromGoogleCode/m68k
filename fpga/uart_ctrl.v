`timescale 1ns / 1ps

module uart_ctrl(
	// system
	input wire sysclk,
	input wire clk,
	input wire rst_n,
	
	// to bus_ctrl
	input wire [7:0] tx_data,
	output wire [7:0] rx_data,

	output wire [7:0] ctrl_out,
	input wire [7:0] ctrl_in,
	
	input wire data_wrh_n,
	input wire data_rdh_n,

	// UART signals	
	input wire rx, // Incoming serial line
	output reg tx, // Outgoing serial line
	
	// interrupt line
	output uart_int_n

);







	reg [7:0] rx_reg;


	
	
	reg prev;
	
	always @(posedge clk)
		prev <= data_rdh_n;
	

	wire rd_n_l;
	assign rd_n_l = data_rdh_n & ~prev;


	wire tx_wr;
	assign tx_wr = ~data_wrh_n;

	wire [7:0] divisor;
	reg rx_done;
	reg tx_done;
	
	assign divisor[7:0] = 8'd33; //clk_freq/baud/16


	
	reg [7:0] fifo [15:0];
	reg [3:0] rd_pt, wr_pt;
	
	reg [4:0] cnt;
	
	wire full, empty;
	assign full = cnt[4]; // == 5'd16;
	assign empty = cnt == 5'd0;

	assign uart_int_n = empty;
	//assign ctrl_out[0] = ~empty;
	//assign ctrl_out[1] = full;
	
	
	always @(posedge clk or negedge rst_n)
		if (~rst_n) begin
			wr_pt <= 4'h0;
			rd_pt <= 4'h0;
			cnt <= 5'h0;
		end else begin
			if (rx_done & ~full) begin
				wr_pt <= wr_pt + 4'h1;
				fifo[wr_pt] <= rx_reg;
			end
			
			if (rd_n_l & ~empty) begin
				rd_pt <= rd_pt + 4'h1;
			end
			
			
			if (rx_done & ~rd_n_l & ~full)
				cnt <= cnt + 5'h1;
			else if (rd_n_l & ~rx_done & ~empty)
				cnt <= cnt - 5'h1;
			
			
				
		end
	
		
	assign rx_data = fifo[rd_pt];
	
	//-----------------------------------------------------------------
	// enable16 generator
	//-----------------------------------------------------------------
	reg [7:0] enable16_counter;

	wire enable16;
	assign enable16 = (enable16_counter == 8'd0);

	always @(posedge clk or negedge rst_n) begin
		if(~rst_n)
			enable16_counter <= divisor - 8'b1;
		else begin
			enable16_counter <= enable16_counter - 8'd1;
			if(enable16)
				enable16_counter <= divisor - 8'b1;
		end
	end

	//-----------------------------------------------------------------
	// Synchronize uart_rx
	//-----------------------------------------------------------------
	reg uart_rx1;
	reg uart_rx2;

	always @(posedge clk) begin
		uart_rx1 <= rx;
		uart_rx2 <= uart_rx1;
	end

	//-----------------------------------------------------------------
	// UART RX Logic
	//-----------------------------------------------------------------
	reg rx_busy;
	reg [3:0] rx_count16;
	reg [3:0] rx_bitcount;
	
	
	

	always @(posedge clk) begin
		if(~rst_n) begin
			rx_done <= 1'b0;
			rx_busy <= 1'b0;
			rx_count16  <= 4'd0;
			rx_bitcount <= 4'd0;
		end else begin
			rx_done <= 1'b0;

			if(enable16) begin
				if(~rx_busy) begin // look for start bit
					if(~uart_rx2) begin // start bit found
						rx_busy <= 1'b1;
						rx_count16 <= 4'd7;
						rx_bitcount <= 4'd0;
					end
				end else begin
					rx_count16 <= rx_count16 + 4'd1;

					if(rx_count16 == 4'd0) begin // sample
						rx_bitcount <= rx_bitcount + 4'd1;

						if(rx_bitcount == 4'd0) begin // verify startbit
							if(uart_rx2)
								rx_busy <= 1'b0;
						end else if(rx_bitcount == 4'd9) begin
							rx_busy <= 1'b0;
							if(uart_rx2) begin // stop bit ok
								//rx_data <= rx_reg;
								rx_done <= 1'b1;
							end // ignore RX error
						end else
							rx_reg <= {uart_rx2, rx_reg[7:1]};
					end
				end
			end
		end
	end

	//-----------------------------------------------------------------
	// UART TX Logic
	//-----------------------------------------------------------------
	reg tx_busy;
	//assign ctrl_out[2] = tx_busy;
	reg [3:0] tx_bitcount;
	reg [3:0] tx_count16;
	reg [7:0] tx_reg;

	always @(posedge clk) begin
		if(~rst_n) begin
			tx_done <= 1'b0;
			tx_busy <= 1'b0;
			tx <= 1'b1;
		end else begin
			tx_done <= 1'b0;
			if(tx_wr) begin
				tx_reg <= tx_data;
				tx_bitcount <= 4'd0;
				tx_count16 <= 4'd1;
				tx_busy <= 1'b1;
				tx <= 1'b0;
			end else if(enable16 && tx_busy) begin
				tx_count16  <= tx_count16 + 4'd1;

				if(tx_count16 == 4'd0) begin
					tx_bitcount <= tx_bitcount + 4'd1;
					
					if(tx_bitcount == 4'd8) begin
						tx <= 1'b1;
					end else if(tx_bitcount == 4'd9) begin
						tx <= 1'b1;
						tx_busy <= 1'b0;
						tx_done <= 1'b1;
					end else begin
						tx <= tx_reg[0];
						tx_reg <= {1'b0, tx_reg[7:1]};
					end
				end
			end
		end
	end


	assign ctrl_out[7:0] = {5'h0, tx_busy, full, ~empty};


endmodule


