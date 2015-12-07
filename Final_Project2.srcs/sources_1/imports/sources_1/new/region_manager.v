`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/24/2015 04:27:36 PM
// Design Name: 
// Module Name: region_manager
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


module region_manager(input wire clk, 
                        input wire [9:0] current_x,
                        input wire [9:0] current_y,
                        input wire [10:0] next_x,
                        input wire [10:0] next_y,
                        input wire [7:0] region_data,
                        input wire new_region_request,
                        input wire reset,
                        input wire lost_led,
                        output reg [17:0] region_addr,
                        output reg [1:0] out_car_region,
                        output reg [1:0] out_next_region);
    
    reg [2:0] state;
    
    reg [1:0] tmp_next;
    reg [1:0] tmp_current;
    
    reg valid_coordinate;
    
    reg addr_split; //0 for first half, 1 for last half
    
    always @(posedge clk) begin
        if(reset) state <= 0;
        else begin
            case(state)
                0: begin
                    if(current_x > 639 || current_y > 479) begin
                        // tmp_current <= 0;
                        tmp_next <= 0;
                        valid_coordinate <= 0;
                        state <= 2;
                    end else begin
                        region_addr <= (current_x + current_y*640) >> 1;
                        addr_split <= (current_x + current_y*640);
                        valid_coordinate <= 1;
                        state <= 1;
                    end
                end
                
                1: state <= 2;
                
                2: begin
                    if(valid_coordinate) begin
                        tmp_current <= addr_split ? region_data[1:0]:region_data[5:4];
                    end
                    
                    if(next_x > 639 || next_x[10] == 1 || next_y > 479 || next_y[10] == 1) begin
                        // tmp_next <= 0;
                        tmp_current <= 0;
                        state <= 0;
                    end else begin
                        region_addr <= (next_x + next_y*640) >> 1;
                        addr_split <= (next_x + next_y*640);
                        state <= 3;
                    end                 
                end
                
                3: state <= 4;
                
                4: begin 
                    tmp_next <= addr_split ? region_data[1:0]:region_data[5:4];
                    state <= 0;
                end
            endcase
        end
    end
    
    always @(tmp_next || lost_led)
        begin
            if(lost_led) begin
                out_car_region <= 0;
                out_next_region <= 0;
            end else begin
                out_car_region <= tmp_current;
                out_next_region <= tmp_next;
            end
          //out_car_region <= tmp_current;
          //out_next_region <= tmp_next;
        end

endmodule
