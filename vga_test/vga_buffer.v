`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:14:50 11/15/2015 
// Design Name: 
// Module Name:    vga_buffer 
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
module vga_buffer(
	input clock,
	input [15:0] din
   );
						
wire every_other = 1;
reg [16:0] addr = 0;

always @ (posedge clock) begin
	we <= 0;
	every_other <= ~every_other;
	if(every_other) begin
		we <= 1;
		addr <= addr + 1;
		din <= pixel_data;
	end
end

endmodule
