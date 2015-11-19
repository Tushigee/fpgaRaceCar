`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   18:27:23 11/15/2015
// Design Name:   vga_buffer
// Module Name:   /afs/athena.mit.edu/user/k/s/kschan/Documents/6.111/Final_Project/vga_test/vga_buffer_test.v
// Project Name:  vga_test
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: vga_buffer
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module vga_buffer_test;

	// Inputs
	reg clock;
	reg [15:0] din;

	// Instantiate the Unit Under Test (UUT)
	vga_buffer uut (
		.clock(clock), 
		.din(din)
	);

	initial begin
		// Initialize Inputs
		clock = 0;
		din = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

	end
      
endmodule

