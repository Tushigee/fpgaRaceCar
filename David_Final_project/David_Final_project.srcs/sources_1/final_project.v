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

debounce #(.DELAY(250000))   // .01 sec with a 25Mhz clock
            brake_debounce(.reset(SW[15]), .clock(clock_25mhz), .noisy(BTND),
             .clean(backward_ctrl));

debounce #(.DELAY(250000))   // .01 sec with a 25Mhz clock
	        hidden_switch_debounce(.reset(SW[15]), .clock(clock_25mhz), .noisy(BTNU),
	         .clean(foward_ctrl));  
	         
debounce #(.DELAY(250000))   // .01 sec with a 25Mhz clock
             reprogram_debounce(.reset(SW[15]), .clock(clock_25mhz), .noisy(BTNC),
              .clean(toggle_autonomous));   	 
              
debounce #(.DELAY(250000))   // .01 sec with a 25Mhz clock
               driver_door_debounce(.reset(SW[15]), .clock(clock_25mhz), .noisy(BTNL),
                .clean(left_ctrl));          
                            
debounce #(.DELAY(250000))   // .01 sec with a 25Mhz clock
             passenger_door_debounce(.reset(SW[15]), .clock(clock_25mhz), .noisy(BTNR),
              .clean(right_ctrl));   
              
synchronize #(.NSYNC(2)) ignition_synchronize(.clk(clock_25mhz), .in(SW[0]),
              .out(manual_control)); 

synchronize #(.NSYNC(2)) time_value_synchronize0(.clk(clock_25mhz), .in(SW[1]),
              .out(car_region[0]));

synchronize #(.NSYNC(2)) time_value_synchronize1(.clk(clock_25mhz), .in(SW[2]),
              .out(car_region[1])); 

synchronize #(.NSYNC(2)) time_value_synchronize2(.clk(clock_25mhz), .in(SW[3]),
              .out(next_region[0]));

synchronize #(.NSYNC(2)) time_value_synchronize3(.clk(clock_25mhz), .in(SW[4]),
              .out(next_region[1]));

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

assign data = {22'b0, next_region, 2'b00, car_region, state[3:0]}; 
                       
//assign LED[14] = siren;    
//assign LED[13] = expired;
//assign LED[12] = flip;



//////////////////////////////////////////////////////////////////////////////////
// sample Verilog to generate color bars
    
    wire [9:0] hcount;
    wire [9:0] vcount;
    wire hsync, vsync, at_display_area;
    vga vga1(.vga_clock(clock_25mhz),.hcount(hcount),.vcount(vcount),
          .hsync(hsync),.vsync(vsync),.at_display_area(at_display_area));
        
    assign VGA_R = at_display_area ? {4{hcount[7]}} : 0;
    assign VGA_G = at_display_area ? {4{hcount[6]}} : 0;
    assign VGA_B = at_display_area ? {4{hcount[5]}} : 0;
    assign VGA_HS = ~hsync;
    assign VGA_VS = ~vsync;
endmodule

///////////////////////////////////////////////////////////////////////////////
//
// 6.111 Final Project - Paper Race Track
// Car Controller Module
//	David Gomez
//	
//clk - 1 bit, 25MHz clock
//reset - 1 bit, reset button
//manual_control - 1 bit, enable manual control switch, active high
//foward_in - 1 bit, manual foward control button, active high
//backward_in - 1 bit, manual backward control button, active high
//left_in - 1 bit, manual left control button, active high
//right_in - 1 bit, manual right control button, active high
//toggle_autonomous - 1 bit, button to toggle autonomous active or inactive, active high
//car_region - 2 bits, the current region of the car 
//next_region - 2 bits, the next region of the car
//**REGIONS**
//  -OUTER_TRACK = 0;
//  -TRACK = 1;
//  -INNER_TRACK = 2;
//  -NULL = 3;
//**REGIONS**
//
//foward_out - 1 bit, foward output control
//backward_out - 1 bit, backward output control
//left_out - 1 bit, left output control
//right_out - 1 bit, right output control
//new_region - 1 bit, request for a new car region to be output, active high
//state - 3 bits, the current state of the controller
//**STATES**
//  -RESET = 0;
//  -MANUAL = 1;
//  -AUTO_SET = 2;
//  -AUTO_F = 3;
//  -AUTO_L = 4;
//  -AUTO_R = 5;
//  -PULSE_COUNT = 6;
//  -NEXT_REGION = 7; 
//  -PRE_L = 8;
//  -PRE_R = 9;
//  -PRE_F = 10;
//**STATES**
///////////////////////////////////////////////////////////////////////////////
module car_controller (input wire clk, 
									input wire reset, //FPGA reset
									input wire manual_control, // enable manual control
									input wire foward_in, // button that controls foward motion
									input wire backward_in, // button that controls backward motion
									input wire left_in, // button that controls left turns
									input wire right_in, // button that controls right turns
									input wire toggle_autonomous, // enables autonomous driving
									input wire [1:0] car_region, //
									input wire [1:0] next_region, //
									output reg foward_out, // output that controls foward motion
									output reg backward_out, // output that controls backward motion
									output reg left_out, // output that controls left turns
									output reg right_out, // output that controls right turns
									output reg new_region,
									output reg [3:0] state); 
									
	reg last_toggle;
	reg auto_enabled;
	
	parameter RESET = 0;
	parameter MANUAL = 1;
	parameter AUTO_SET = 2;
	parameter AUTO_F = 3;
	parameter AUTO_L = 4;
	parameter AUTO_R = 5;
	parameter PULSE_COUNT = 6;
	parameter NEXT_REGION = 7; 
	parameter PRE_L = 8;
	parameter PRE_R = 9;
	parameter PRE_F = 10;
	
	parameter OUTER_TRACK = 0;
    parameter TRACK = 1;
    parameter INNER_TRACK = 2;
    
    parameter CMD_DELAY = 24'd25000000;
    parameter FWD_PULSE = 24'd800000; //d800000, 810000
    parameter LEFT_PULSE = 24'd2000000; //d1250000, 810000
    parameter RIGHT_PULSE = 24'd2150000; //d1400000, 810000
    parameter PRE_LEFT_PULSE = 24'd2000000; //d2000000, 810000
    parameter PRE_RIGHT_PULSE = 24'd2150000; //d2150000, 810000
    parameter BACK_PULSE = 24'd1250000; //d2150000, 810000
	
	reg [24:0] pulse_length;
	reg [24:0] pulse_count;
	
	always @(posedge clk)
		begin
			last_toggle <= toggle_autonomous;
			auto_enabled <= ((!last_toggle & toggle_autonomous)) ? ~auto_enabled:auto_enabled;
			
			if(reset)
				begin
					auto_enabled <= 0;
					foward_out <= 0;
					backward_out <= 0;
					left_out <= 0;
					right_out <= 0;
					state <= RESET;
				end
			else if(manual_control)
				begin
					auto_enabled <= 0;
					foward_out <= foward_in;
					backward_out <= backward_in;
					left_out <= left_in;
					right_out <= right_in;
					state <= MANUAL;
				end
			else if(auto_enabled)					
                begin
                    case(state)
                        AUTO_SET:
                            begin
                                case(car_region)
                                    OUTER_TRACK:
                                        begin
                                            case(next_region)
                                                OUTER_TRACK: state <= AUTO_R;
                                                TRACK: state <= AUTO_F;
                                                INNER_TRACK: state <= AUTO_L;
                                                default: state <= NEXT_REGION;
                                            endcase
                                        end
                                    TRACK:
                                        begin
                                            case(next_region)
                                                OUTER_TRACK: state <= AUTO_R;
                                                TRACK: state <= AUTO_F;
                                                INNER_TRACK: state <= AUTO_L;
                                                default: state <= NEXT_REGION;
                                            endcase
                                        end
                                    INNER_TRACK:
                                        begin 
                                            case(next_region)
                                                OUTER_TRACK: state <= AUTO_R;
                                                TRACK: state <= AUTO_F;
                                                INNER_TRACK: state <= AUTO_L;
                                                default: state <= NEXT_REGION;
                                            endcase
                                        end
                                    default: state <= NEXT_REGION;
                                endcase
                            end
                            
                        AUTO_F:
                            begin
                                foward_out <= 1;
                                backward_out <= 0;
                                left_out <= 0;
                                right_out <= 0;
                                pulse_length <= FWD_PULSE;
                                pulse_count <= 0;
                                state <= PRE_F;
                            end
                            
                        AUTO_L:
                            begin
                                foward_out <= 0;
                                backward_out <= 0;
                                left_out <= 1;
                                right_out <= 0;
                                pulse_length <= PRE_LEFT_PULSE;
                                pulse_count <= 0;
                                state <= PRE_L;
                            end
                            
                        AUTO_R:
                            begin
                                foward_out <= 0;
                                backward_out <= 0;
                                left_out <= 0;
                                right_out <= 1;
                                pulse_length <= PRE_RIGHT_PULSE;
                                pulse_count <= 0;
                                state <= PRE_R;
                            end
                        
                        PRE_L:
                            begin
                                if(pulse_count == pulse_length)
                                    begin
                                        foward_out <= 1;
                                        pulse_length <= LEFT_PULSE;
                                        pulse_count <= 0;
                                        state <= PULSE_COUNT;
                                    end
                                else
                                    begin
                                        pulse_count <= pulse_count + 1;
                                        state <= PRE_L;
                                    end
                            end
                        
                        PRE_R:
                            begin
                                if(pulse_count == pulse_length)
                                    begin
                                        foward_out <= 1;
                                        pulse_length <= RIGHT_PULSE;
                                        pulse_count <= 0;
                                        state <= PULSE_COUNT;
                                    end
                                else
                                    begin
                                        pulse_count <= pulse_count + 1;
                                        state <= PRE_R;
                                    end
                            end
                        
                        PRE_F:
                            begin
                                if(pulse_count == pulse_length)
                                    begin
                                        foward_out <= 0;
                                        backward_out <= 0;
                                        pulse_length <= BACK_PULSE;
                                        pulse_count <= 0;
                                        state <= PULSE_COUNT;
                                    end
                                else
                                    begin
                                        pulse_count <= pulse_count + 1;
                                        state <= PRE_F;
                                    end
                            end
                        
                        PULSE_COUNT:
                            begin
                                if(pulse_count == pulse_length)
                                    begin
                                        pulse_count <= 0;
                                        state <= NEXT_REGION;
                                    end
                                else
                                    begin
                                        pulse_count <= pulse_count + 1;
                                        state <= PULSE_COUNT;
                                    end
                            end
                        
                        NEXT_REGION:
                            begin
                                foward_out <= 0;
                                backward_out <= 0;
                                pulse_count <= 0;
                                if(new_region)
                                    begin
                                        new_region = 0;
                                        pulse_length <= 0;
                                        state <= AUTO_SET;
                                    end
                                else
                                    begin
                                        new_region = 1;
                                        pulse_length <= CMD_DELAY;
                                        state <= PULSE_COUNT; 
                                    end                                   
                            end
                            
                        default
                            begin
                                foward_out <= 0;
                                backward_out <= 0;
                                left_out <= 0;
                                right_out <= 0;
                                state <= AUTO_SET;
                            end
                    endcase
                end
            else
                begin
                    foward_out <= 0;
                    backward_out <= 0;
                    left_out <= 0;
                    right_out <= 0;
                    state <= AUTO_SET;
                end
		end

endmodule



module clock_quarter_divider(input clk100_mhz, output reg clock_25mhz = 0);
    reg counter = 0;
    
    always @(posedge clk100_mhz) begin
        counter <= counter + 1;
        if (counter == 0) begin
            clock_25mhz <= ~clock_25mhz;
        end
    end
endmodule

module vga(input vga_clock,
            output reg [9:0] hcount = 0,    // pixel number on current line
            output reg [9:0] vcount = 0,	 // line number
            output vsync, hsync, at_display_area);
    // Counters.
    always @(posedge vga_clock) begin
        if (hcount == 799) begin
            hcount <= 0;
        end
        else begin
            hcount <= hcount +  1;
        end
        if (vcount == 524) begin
            vcount <= 0;
        end
        else if(hcount == 799) begin
            vcount <= vcount + 1;
        end
    end
    
    assign hsync = (hcount < 96);
    assign vsync = (vcount < 2);
    assign at_display_area = (hcount >= 144 && hcount < 784 && vcount >= 35 && vcount < 515);
endmodule


