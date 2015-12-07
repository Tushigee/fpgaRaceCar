`timescale 1ns / 1ps
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
    
    parameter CMD_DELAY = 24'd5000000;
    parameter FWD_PULSE = 24'd800000; //d800000, 810000
    parameter LEFT_PULSE = 24'd2000000; //d1250000, 810000
    parameter RIGHT_PULSE = 24'd2150000; //d1400000, 810000
    parameter PRE_LEFT_PULSE = 24'd2000000; //d2000000, 810000
    parameter PRE_RIGHT_PULSE = 24'd2150000; //d2150000, 810000
    parameter FWD_DELAY = 24'd10000000; //d2150000, 810000
	
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
                                        pulse_length <= FWD_DELAY;
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
