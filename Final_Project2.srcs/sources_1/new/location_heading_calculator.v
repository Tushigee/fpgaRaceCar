`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/30/2015 05:40:59 PM
// Design Name: 
// Module Name: location_heading_calculator
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


module location_heading_calculator(
    input clock,
    input vsync_disp,
    input [9:0] last_com_x1,
    input [9:0] last_com_y1,
    input [9:0] last_com_x2,
    input [9:0] last_com_y2,
    output reg [9:0] current_x,
    output reg [9:0] current_y,
    output reg [10:0] next_x,
    output reg [10:0] next_y
    );
    
    reg [10:0] sum_x;
    reg [10:0] sum_y;
    reg [9:0] last_x, last_y;
    reg last_vsync_disp;
    reg moving_right, moving_down;
    
    always @(posedge clock) begin
        last_vsync_disp <= vsync_disp;
        if (vsync_disp == 0 & last_vsync_disp == 1) begin       
            last_x <= current_x;
            last_y <= current_y;
            
            sum_x <= last_com_x1 + last_com_x2;
            current_x <= sum_x >> 1;
            
            sum_y <= last_com_y1 + last_com_y2;
            current_y <= sum_y >> 1;
            
            if ((last_x < current_x - 1)|(moving_right&~(last_x > current_x))) begin   //moving right
                moving_right <= 1;
                if (last_com_x1 > last_com_x2)  //com1 leading
                    next_x <= current_x+last_com_x1+last_com_x1+last_com_x1+last_com_x1+last_com_x1+last_com_x1-last_com_x2-last_com_x2-last_com_x2-last_com_x2-last_com_x2-last_com_x2;
                else    //com2 leading
                    next_x <= current_x+last_com_x2+last_com_x2+last_com_x2+last_com_x2+last_com_x2+last_com_x2-last_com_x1-last_com_x1-last_com_x1-last_com_x1-last_com_x1-last_com_x1;
            end else if ((last_x > current_x + 1)|(~moving_right&~(last_x < current_x))) begin  //moving left
                moving_right <= 0;
                if (last_com_x1 > last_com_x2)  //com2 leading
                    next_x <= current_x+last_com_x2+last_com_x2+last_com_x2+last_com_x2+last_com_x2+last_com_x2-last_com_x1-last_com_x1-last_com_x1-last_com_x1-last_com_x1-last_com_x1;
                else    //com1 leading
                    next_x <= current_x+last_com_x1+last_com_x1+last_com_x1+last_com_x1+last_com_x1+last_com_x1-last_com_x2-last_com_x2-last_com_x2-last_com_x2-last_com_x2-last_com_x2;
            end else
                next_x <= next_x;
            
            if ((last_y < current_y - 1)|(moving_down&~(last_y > current_y))) begin   //moving down
                moving_down <= 1;
                if (last_com_y1 > last_com_y2)  //com1 leading
                    next_y <= current_y+last_com_y1+last_com_y1+last_com_y1+last_com_y1+last_com_y1+last_com_y1-last_com_y2-last_com_y2-last_com_y2-last_com_y2-last_com_y2-last_com_y2;
                else    //com2 leading
                    next_y <= current_y+last_com_y2+last_com_y2+last_com_y2+last_com_y2+last_com_y2+last_com_y2-last_com_y1-last_com_y1-last_com_y1-last_com_y1-last_com_y1-last_com_y1;
            end else if ((last_y > current_y + 1)|(~moving_down&~(last_y < current_y))) begin  //moving up
                moving_down <= 0;
                if (last_com_y1 > last_com_y2)  //com2 leading
                    next_y <= current_y+last_com_y2+last_com_y2+last_com_y2+last_com_y2+last_com_y2+last_com_y2-last_com_y1-last_com_y1-last_com_y1-last_com_y1-last_com_y1-last_com_y1;
                else    //com1 leading
                    next_y <= current_y+last_com_y1+last_com_y1+last_com_y1+last_com_y1+last_com_y1+last_com_y1-last_com_y2-last_com_y2-last_com_y2-last_com_y2-last_com_y2-last_com_y2;
            end else
                next_y <= next_y;
        end
    end
    
endmodule
