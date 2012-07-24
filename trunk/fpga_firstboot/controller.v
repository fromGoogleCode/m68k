// Main controller for Alcetronics M68K board FPGA
// Initial FLASH loader
//
// 2012.03.28, ljalves, Created
//
//



module controller(
	//system
	input wire rst_n,
	input wire clk,
	
	
	input wire [2:0] cpu_fc,
	inout wire [23:1] cpu_addrbus,
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
	);
	
	
	
	reg [7:0] STATE;
	
	always @(posedge clk) begin
		if (!rst_n) begin
			
		
		end else begin
		
			case (STATE)
				8'h0: begin
					
				
				end
		
		
		
		
		
		
		
		
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
endmodule