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
    output reg [9:0] leading_y
    );
    
    reg [10:0] sum_x;
    reg [10:0] sum_y;
    reg [9:0] last_x, last_y;
    reg [9:0] leading_x, leading_y, trailing_x, trailing_y = 0;

    reg last_vsync_disp;
    
    reg state = 0;
    
    wire [9:0] x_diff1, y_diff1, x_diff2, y_diff2;
    assign x_diff1 = (leading_x > last_com_x1)?(leading_x-last_com_x1):(last_com_x1-leading_x);
    assign y_diff1 = (leading_y > last_com_y1)?(leading_y-last_com_y1):(last_com_y1-leading_y);
    assign x_diff2 = (leading_x > last_com_x2)?(leading_x-last_com_x2):(last_com_x2-leading_x);
    assign y_diff2 = (leading_y > last_com_y2)?(leading_y-last_com_y2):(last_com_y2-leading_y);
    
    always @(posedge clock) begin
        last_vsync_disp <= vsync_disp;
        if(vsync_disp == 0 & last_vsync_disp == 1) begin
            sum_x <= last_com_x1 + last_com_x2;
            current_x <= sum_x >> 1;
            
            sum_y <= last_com_y1 + last_com_y2;
            current_y <= sum_y >> 1;
            
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
//            end else if (last_com_x2 == 0 & last_com_y2 == 0) begin //lost sight of at least one LED
//                leading_x <= leading_x;
//                leading_y <= leading_y;
//                trailing_x <= trailing_x;
//                trailing_y <= trailing_y;
//                current_x <= 700;   //return an invalid location so that we turn right
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
//        case(state)
//            0: begin
//                state <= 1;
//                if (last_x < current_x - 1) begin   //moving right

//                    if (last_com_x1 > last_com_x2)  //com1 leading
//                        possible_next_x <= current_x+last_com_x1+last_com_x1+last_com_x1+last_com_x1+last_com_x1+last_com_x1-last_com_x2-last_com_x2-last_com_x2-last_com_x2-last_com_x2-last_com_x2;
//                    else    //com2 leading
//                        possible_next_x <= current_x+last_com_x2+last_com_x2+last_com_x2+last_com_x2+last_com_x2+last_com_x2-last_com_x1-last_com_x1-last_com_x1-last_com_x1-last_com_x1-last_com_x1;
                
//                end else if (last_x > current_x + 1) begin  //moving left
//                    if (last_com_x1 > last_com_x2)  //com2 leading
//                        possible_next_x <= current_x+last_com_x2+last_com_x2+last_com_x2+last_com_x2+last_com_x2+last_com_x2-last_com_x1-last_com_x1-last_com_x1-last_com_x1-last_com_x1-last_com_x1;
//                    else    //com1 leading
//                        possible_next_x <= current_x+last_com_x1+last_com_x1+last_com_x1+last_com_x1+last_com_x1+last_com_x1-last_com_x2-last_com_x2-last_com_x2-last_com_x2-last_com_x2-last_com_x2;
                
//                end else
//                    possible_next_x <= next_x;
                
//                if (last_y < current_y - 1) begin   //moving down
//                    if (last_com_y1 > last_com_y2)  //com1 leading
//                        possible_next_y <= current_y+last_com_y1+last_com_y1+last_com_y1+last_com_y1+last_com_y1+last_com_y1-last_com_y2-last_com_y2-last_com_y2-last_com_y2-last_com_y2-last_com_y2;
//                    else    //com2 leading
//                        possible_next_y <= current_y+last_com_y2+last_com_y2+last_com_y2+last_com_y2+last_com_y2+last_com_y2-last_com_y1-last_com_y1-last_com_y1-last_com_y1-last_com_y1-last_com_y1;
                
//                end else if (last_y > current_y + 1) begin  //moving up
//                    if (last_com_y1 > last_com_y2)  //com2 leading
//                        possible_next_y <= current_y+last_com_y2+last_com_y2+last_com_y2+last_com_y2+last_com_y2+last_com_y2-last_com_y1-last_com_y1-last_com_y1-last_com_y1-last_com_y1-last_com_y1;
//                    else    //com1 leading
//                        possible_next_y <= current_y+last_com_y1+last_com_y1+last_com_y1+last_com_y1+last_com_y1+last_com_y1-last_com_y2-last_com_y2-last_com_y2-last_com_y2-last_com_y2-last_com_y2;
                
//                end else
//                    possible_next_y <= next_y;
//            end
            
//            1: begin
//                if(vsync_disp == 0 & last_vsync_disp == 1) begin
//                    state <= 0;
//                    last_x <= current_x;
//                    last_y <= current_y;
//                    last_predicted_x <= next_x;
//                    last_predicted_y <= next_y;
//                end
                
//                if ((possible_next_x > (last_predicted_x + 75))|(possible_next_x < (last_predicted_x - 75))|(possible_next_y > (last_predicted_y + 75))|(possible_next_y < (last_predicted_y - 75)))
//                    next_x <= last_predicted_x;
//                else
//                    next_x <= possible_next_x;
//            end
//        endcase
//        end
    end
    
endmodule
