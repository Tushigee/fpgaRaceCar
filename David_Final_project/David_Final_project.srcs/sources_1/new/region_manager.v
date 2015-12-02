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
                        input wire [10:0] current_x,
                        input wire [9:0] current_y,
                        input wire [10:0] new_x,
                        input wire [9:0] new_y,
                        input wire [7:0] region_data,
                        input wire new_region_request,
                        output reg [17:0] region_addr,
                        output reg [1:0] out_car_region,
                        output reg [1:0] out_next_region);
    
    reg [1:0] state;
    
    reg [1:0] tmp_next;
    reg [1:0] tmp_current;
    
    reg valid_coordinate;
    
    reg addr_split; //0 for first half, 1 for last half
    
    always @(posedge clk) begin
        if(reset) state <= 0;
        else begin
            case(state)
                0: begin
                    if(current_x > 639 || current_x[10] == 1 || current_y > 479 || current_y[9] == 1) begin
                        tmp_current <= 0;
                        valid_coordinate <= 0;
                    end else begin
                        region_addr <= (next_x + next_y*640) >> 1;
                        addr_split <= (next_x + next_y*640) % 2;
                        valid_coordinate <= 1;
                    end
                    
                    state <= 1;
                end
                
                1: begin
                    if(valid_coordinate) begin
                        tmp_current <= addr_split ? region_data[1:0]:region_data[5:4];
                    end
                    
                    if(new_x > 639 || new_x[10] == 1 || new_y > 479 || new_y[9] == 1) begin
                        tmp_next <= 0;
                        state <= 0;
                    end else begin
                        region_addr <= (current_x + current_y*640) >> 1;
                        addr_split <= (current_x + current_y*640) % 2;
                        state <= 2;
                    end                 
                end
                
                2: begin 
                    tmp_next <= addr_split ? region_data[1:0]:region_data[5:4];
                    state <= 0;
                end
            endcase
        end
    end
    
    always @(posedge new_region_request)
        begin
          out_car_region <= tmp_current;
          out_next_region <= tmp_next;
        end

endmodule
