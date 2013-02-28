module i2c_ctrl(
	// system
	input wire sysclk,
	input wire clk,
	input wire rst_n,
	
	// to bus_ctrl
	input wire [7:0] datain,
	output wire [7:0] dataout,

	output reg [7:0] ctrl_out,
	input wire [7:0] ctrl_in,
	
	input wire data_wrh_n,
	input wire data_wrl_n,
	input wire data_rdh_n,

	// UART signals	
	inout wire sda,
	inout wire sck,
	
	// interrupt line
	output reg i2c_int_n
);


	reg sda_out, sck_out;
	assign sda = sda_out ? 1'bz : 1'b0;
	assign sck = sck_out ? 1'bz : 1'b0;



	// detect neg edge on wr_ctrl
	reg wr_ctrl_d;
	always @(posedge clk or negedge rst_n)
		if (~rst_n)
			wr_ctrl_d <= 0;
		else	
			wr_ctrl_d <= data_wrl_n;

	wire wr_ctrl;
	assign wr_ctrl = (data_wrl_n) & (~wr_ctrl_d);


	// control register
	reg ackin;
	reg sta, sto, rd, wr;
	reg [3:0] state;


	wire busy = (|state);

	always @(posedge clk or negedge rst_n)
		if (~rst_n) begin
			sta <= 0;
			sto <= 0;
			rd <= 0;
			wr <= 0;
			ctrl_out <= 8'h00;
		end else begin
			ctrl_out <= {6'h0, busy, ackin};


			if (wr_ctrl) begin
				sta <= ctrl_in[0];
				sto <= ctrl_in[1];
				rd <= ctrl_in[2];
				wr <= ctrl_in[3];
			end else begin
				sta <= 0;
				sto <= 0;
				rd <= 0;
				wr <= 0;
			end
		end
	
	wire ack = ctrl_in[4];

	reg [5:0] clkcnt;
	wire ena;
	assign ena = ~|clkcnt;

	always @(posedge clk)
		if(|clkcnt & |state)
			clkcnt <= clkcnt - 6'h1;
		else
			clkcnt <= 6'h3f;   // 128

		

	parameter IDLE  = 4'h0;
	parameter START1  = 4'h1;
	parameter START2  = 4'h2;
	parameter START3  = 4'h3;
	parameter START4  = 4'h4;
	parameter STOP1  = 4'h5;
	parameter STOP2  = 4'h6;
	parameter STOP3  = 4'h7;
	parameter DT1  = 4'h8;
	parameter DT2  = 4'h9;
	parameter DT3  = 4'hA;
	parameter DT4  = 4'hB;
	parameter DT5  = 4'hC;
	parameter DT6  = 4'hD;
	parameter DT7  = 4'hE;

	reg [7:0] txreg, rxreg;
	reg [2:0] bcnt;
	
	reg isRx;

	always @(posedge clk or negedge rst_n)
		if (~rst_n) begin
			sda_out <= 1;	// hiZ
			sck_out <= 1;	// hiZ

			bcnt <= 3'h7;
			txreg[7:0] <= 8'h0;
			rxreg[7:0] <= 8'h0;
			state <= IDLE;

			isRx <= 1;
			ackin <= 0;
			//dataout <= 8'hAC;

		end else begin
			case (state)
				IDLE: begin
					//sda_out <= 1;
					//sck_out <= 1;
					bcnt <= 3'h7;
					txreg <= datain;
					//dataout <= rxreg;

					if (sta)
						state <= START1;
					else if (sto)
						state <= STOP1;
					else if (rd | wr)
						state <= DT1;
					else
						state <= IDLE;

					if (wr)
						isRx <= 0;
					else
						isRx <= 1;
					
				end

				START1: begin
					sda_out <= 1;
					if (ena)
						state <= START2;
				end
				START2: begin
					sck_out <= 1;
					if (ena)
						state <= START3;
				end
				START3: begin
					sda_out <= 0;
					if (ena)
						state <= START4;
				end
				START4: begin
					sck_out <= 0;
					if (ena)
						state <= IDLE;
				end

				STOP1: begin
					sda_out <= 0;
					sck_out <= 0;
					if (ena)
						state <= STOP2;
				end
				STOP2: begin
					sck_out <= 1;
					if (ena)
						state <= STOP3;
				end
				STOP3: begin
					sda_out <= 1;
					if (ena)
						state <= IDLE;
				end


				DT1: begin
					sda_out <= txreg[7] | isRx;
					if (ena)
						state <= DT2;
				end
				DT2: begin
					sck_out <= 1;
					if (ena) begin
						txreg[7:1] <= txreg[6:0];
						state <= DT3;
					end
				end
				DT3: begin
					if (ena) begin
						rxreg[7:0] <= {rxreg[6:0], sda};
						state <= DT4;
					end
				end
				DT4: begin
					sck_out <= 0;
					if (ena) begin
						bcnt <= bcnt - 3'h1;
						if (~|bcnt) begin
							state <= DT5;
						end else begin
							state <= DT1;
						end
					end
				end


				DT5: begin
					sda_out <= ack;
					if (ena)
						state <= DT6;
				end
				DT6: begin
					sck_out <= 1;
					if (ena) begin
						ackin <= sda;
						state <= DT7;
					end
				end
				DT7: begin
					sck_out <= 0;
					if (ena) begin
						state <= IDLE;
					end
				end

			endcase


		end



	assign dataout = rxreg;


endmodule
