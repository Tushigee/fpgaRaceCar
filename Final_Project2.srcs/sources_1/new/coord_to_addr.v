`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/24/2015 03:38:15 PM
// Design Name: 
// Module Name: coord_to_addr
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module addr_to_coord(
    input clock_25mhz,
    input [17:0] addr,
    output reg [10:0] pixel_x,
    output reg [10:0] pixel_y,
    output reg done
    );
    
    reg [18:0] pixel_index;
    
    
    always @(posedge clock_25mhz) begin
        pixel_index <= addr << 1;
    end
    
endmodule
