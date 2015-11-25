`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/23/2015 09:45:34 PM
// Design Name: 
// Module Name: camera_read
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


module camera_read(
    input clock_25mhz,
    input start,
    input [7:0] camera_data,
    input PCLK,
    input VSYNC,
    input HREF,
    output reg [17:0] bram_addr,
    output reg [7:0] bram_din,
    output reg bram_we,
    input threshold_on,
    input [7:0] threshold,
    output SIOC,
    output SIOD
    );
    
    wire config_done;
    camera_configure OV7670_config(.clk(clock_25mhz), .start(start), .sioc(SIOC), .siod(SIOD), .done(config_done));
    
    reg [1:0] byte_counter = 0;
    reg [3:0] intense_byte, intense_byte1;
    reg vsync_prev;
    
    // FSM/BRAM
    localparam WAITING = 0;
    localparam RECORD = 1;
    reg status = WAITING;
    
    always @ (posedge PCLK) begin
        vsync_prev <= VSYNC;
        if (bram_addr == 153600) begin
            bram_addr <= 0;
            status <= WAITING;
        end else begin
            case(status)
                WAITING: begin
                    if (VSYNC == 0 & vsync_prev == 1) status <= RECORD;
                end
                // Made BRAM to hold two pixels at the same time
                RECORD: begin
                    if (VSYNC == 1) status <= WAITING;
                    else if (HREF == 1) begin    
                        byte_counter <= byte_counter + 1;
                        case(byte_counter)
                            0: begin    // Write two values we stored
                                bram_we <= 1;
                                bram_addr <= bram_addr + 1;
                                bram_din <= {intense_byte, intense_byte1};
                            end
                            1: begin
                                if (threshold_on == 0) intense_byte <= camera_data[7:4];
                                else if(camera_data>threshold) intense_byte <= 4'hF;
                                else intense_byte <= 0;
                                bram_we <= 0;
                            end 
                            2: begin end
                            3: begin
                                if (threshold_on == 0) intense_byte1 <= camera_data[7:4]; 
                                else if (camera_data > threshold) intense_byte1 <= 4'hF;
                                else intense_byte1 <= 0;
                            end
                        endcase
                    end
                end
            endcase
        end
    end
    
endmodule
