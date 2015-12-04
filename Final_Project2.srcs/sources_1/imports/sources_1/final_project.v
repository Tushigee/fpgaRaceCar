`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// 
// Create Date: 10/1/2015 V1.0
// Design Name: 
// Module Name: labkit
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


module labkit(
   input CLK100MHZ,
   input[15:0] SW, 
   input BTNC, BTNU, BTNL, BTNR, BTND, CPU_RESETN,
   output[3:0] VGA_R, 
   output[3:0] VGA_B, 
   output[3:0] VGA_G,
   output[7:0] JA, 
   output VGA_HS, 
   output VGA_VS, 
   output LED16_B, LED16_G, LED16_R,
   output LED17_B, LED17_G, LED17_R,
   output[15:0] LED,
   output[7:0] SEG,  // segments A-G (0-6), DP (7)
   output[7:0] AN,   // Display 0-7
   output[3:0] JD
   );
   

// create 25mhz system clock
    wire clock_25mhz;
    clock_quarter_divider clockgen(.clk100_mhz(CLK100MHZ), .clock_25mhz(clock_25mhz));

//  instantiate 7-segment display;  
    wire [31:0] data;
    wire [6:0] segments;
    display_8hex display(.clk(clock_25mhz),.data(data), .seg(segments), .strobe(AN));    
    assign SEG[6:0] = segments;
    assign SEG[7] = 1'b1;

//////////////////////////////////////////////////////////////////////////////////
//
//  remove these lines and insert your lab here

wire foward_ctrl;
wire backward_ctrl;
wire left_ctrl;
wire right_ctrl;
wire toggle_autonomous;

wire manual_control;
wire [1:0] car_region;
wire [1:0] next_region;

wire [3:0] state;

wire reset; 
assign reset = ~CPU_RESETN;


car_controller car_controller(.clk(clock_25mhz), 
                        .reset(reset), //FPGA reset
                        .manual_control(manual_control), // enable manual control
                        .foward_in(foward_ctrl), // button that controls foward motion
                        .backward_in(backward_ctrl), // button that controls backward motion
                        .left_in(left_ctrl), // button that controls left turns
                        .right_in(right_ctrl), // button that controls right turns
                        .toggle_autonomous(toggle_autonomous), // enables autonomous driving
                        .car_region(car_region), //
                        .next_region(next_region), //
                        .foward_out(JD[0]), // output that controls foward motion
                        .backward_out(JD[1]), // output that controls backward motion
                        .left_out(JD[2]), // output that controls left turns
                        .right_out(JD[3]), // output that controls right turns
                        .new_region(LED16_B),
                        .state(state));
endmodule