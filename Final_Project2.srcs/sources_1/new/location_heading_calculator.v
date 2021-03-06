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
    input button,
    output reg [9:0] current_x,
    output reg [9:0] current_y,
    output reg [10:0] next_x,
    output reg [10:0] next_y,
    output reg [9:0] leading_x,
    output reg [9:0] leading_y,
    output reg lost_led
    );
    
    reg [10:0] sum_x;
    reg [10:0] sum_y;
    reg [9:0] last_x, last_y;
    reg [9:0] leading_x, leading_y, trailing_x, trailing_y = 0;
    reg [10:0] last_predicted_x, last_predicted_y;

    reg last_vsync_disp;
    
    reg state = 0;
    
    wire [9:0] x_diff1, y_diff1, x_diff2, y_diff2;
    assign x_diff1 = (last_predicted_x > last_com_x1)?(last_predicted_x-last_com_x1):(last_com_x1-last_predicted_x);
    assign y_diff1 = (last_predicted_y > last_com_y1)?(last_predicted_y-last_com_y1):(last_com_y1-last_predicted_y);
    assign x_diff2 = (last_predicted_x > last_com_x2)?(last_predicted_x-last_com_x2):(last_com_x2-last_predicted_x);
    assign y_diff2 = (last_predicted_y > last_com_y2)?(last_predicted_y-last_com_y2):(last_com_y2-last_predicted_y);
    
    always @(posedge clock) begin
        last_vsync_disp <= vsync_disp;
        if(vsync_disp == 0 & last_vsync_disp == 1) begin
            lost_led <= 0;
            sum_x <= last_com_x1 + last_com_x2;
            current_x <= sum_x >> 1;
            
            sum_y <= last_com_y1 + last_com_y2;
            current_y <= sum_y >> 1;
            
            last_predicted_x <= (next_x[10] == 1)? 0:next_x;
            last_predicted_y <= (next_y[10] == 1)? 0:next_y;
            
            if (button) begin
                if (last_com_x1 < last_com_x2) begin    //leading point is the leftmost
                    leading_x <= last_com_x1;
                    leading_y <= last_com_y1;
                    trailing_x <= last_com_x2;
                    trailing_y <= last_com_y2;
                end else begin
                    leading_x <= last_com_x2;
                    leading_y <= last_com_y2;
                    trailing_x <= last_com_x1;
                    trailing_y <= last_com_y1;
                end
            end else if ((last_com_x2 > 800) & (last_com_y2 > 800) == 0) begin //lost sight of at least one LED
                leading_x <= leading_x;
                leading_y <= leading_y;
                trailing_x <= trailing_x;
                trailing_y <= trailing_y;
                lost_led <= 1;   //return an invalid location so that we turn right
            end else begin
                next_x <= current_x + leading_x+leading_x+leading_x+leading_x+leading_x+leading_x-trailing_x-trailing_x-trailing_x-trailing_x-trailing_x-trailing_x;
                next_y <= current_y + leading_y+leading_y+leading_y+leading_y+leading_y+leading_y-trailing_y-trailing_y-trailing_y-trailing_y-trailing_y-trailing_y;
                if (x_diff1+y_diff1 < x_diff2+y_diff2) begin
                    leading_x <= last_com_x1;
                    leading_y <= last_com_y1;
                    trailing_x <= last_com_x2;
                    trailing_y <= last_com_y2;
                end else begin
                    leading_x <= last_com_x2;
                    leading_y <= last_com_y2;
                    trailing_x <= last_com_x1;
                    trailing_y <= last_com_y1;
                end
            end
        end
    end
    
endmodule
