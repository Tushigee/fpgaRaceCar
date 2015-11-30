`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/30/2015 02:59:20 PM
// Design Name: 
// Module Name: com_finder
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


module com_finder(
    input clock,
    input first_byte,
    input [9:0] hcount,
    input [9:0] vcount,
    input vsync_disp,
    input [7:0] camera_dout,
    output reg [9:0] last_com_x1,
    output reg [9:0] last_com_y1,
    output reg [9:0] last_com_x2,
    output reg [9:0] last_com_y2
    );
    
    reg [9:0] com_x1, com_x2 = 10'h0;
    reg [9:0] com_y1, com_y2 = 10'h0;
    
    reg last_vsync_disp;
    
    always @(posedge clock) begin
        last_vsync_disp <= vsync_disp;
        if(vsync_disp == 0 & last_vsync_disp == 1) begin
            last_com_x1 <= com_x1;
            last_com_y1 <= com_y1;
            com_x1 <= 0;
            com_y1 <= 0;
            
            last_com_x2 <= com_x2;
            last_com_y2 <= com_y2;
            com_x2 <= 0;
            com_y2 <= 0;
        end else if (first_byte) begin
            if (camera_dout[7:4] == 4'hF & ((vcount>(com_y1 + 50))|(vcount<com_y1)|(hcount<(com_x1-25))|(hcount>(com_x1+25)))
                & ((vcount>(com_y2+50))|(vcount<com_y2)|(hcount<(com_x2-25))|(hcount>(com_x2+25)))) begin  //white pixel and far enough away from previous com
                if (com_x1 == 0) begin
                    com_x1 <= hcount;
                    com_y1 <= vcount;
                end else if (com_x2 == 0) begin
                    com_x2 <= hcount;
                    com_y2 <= vcount;
                end
            end

        end else if (~first_byte) begin
            if (camera_dout[3:0] == 4'hF & ((vcount>(com_y1 + 50))|(vcount<com_y1)|(hcount<(com_x1-25))|(hcount>(com_x1+25)))
                & ((vcount>(com_y2+50))|(vcount<com_y2)|(hcount<(com_x2-25))|(hcount>(com_x2+25)))) begin  //white pixel and far enough away from previous com
                if (com_x1 == 0) begin
                    com_x1 <= hcount;
                    com_y1 <= vcount;
                end else if (com_x2 == 0) begin
                    com_x2 <= hcount;
                    com_y2 <= vcount;
                end
            end
        end
    end
endmodule
