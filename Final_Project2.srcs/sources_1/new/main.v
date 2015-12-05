`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2015 11:02:12 PM
// Design Name: 
// Module Name: main
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


module main(
    input CLK100MHZ,
    input BTNC, BTNU, BTNL, BTNR, BTND, CPU_RESETN,
    input [7:0] JA,
    input [15:0] SW, 
    inout [7:0] JB,
    inout [7:0] JC,
    output [3:0] VGA_R, 
    output [3:0] VGA_B,
    output [3:0] VGA_G,
    output VGA_HS, 
    output VGA_VS,
    output[7:0] SEG,  // segments A-G (0-6), DP (7)
    output[15:0] LED,
    output[7:0] AN,    // Display 0-7
    output [7:0] JD,
    output LED16_B, LED16_G, LED16_R,
    output LED17_B, LED17_G, LED17_R
    );
    
    assign LED[13:0] = SW[13:0];  
    
    wire clock_25mhz;
    clock_quarter_divider clockgen(.clk100_mhz(CLK100MHZ), .clock_25mhz(clock_25mhz));

//  instantiate 7-segment display;  
    wire [31:0] data;
    wire [6:0] segments;
    reg [16:0] camera_rgb_disp;
    display_8hex display(.clk(clock_25mhz), .data(data), .seg(segments), .strobe(AN));    
    assign SEG[6:0] = segments;
    assign SEG[7] = 1'b1;
    assign data = {24'b0 ,2'b0,next_region, 2'b0,car_region};

    wire SIOD;
    wire SIOC;
    wire PCLK;
    wire VSYNC;
    wire HREF;
    wire RESET;
    wire PWDN;

    wire [7:0] camera_data;

    assign PCLK = JB[7];
    assign JB[3] = clock_25mhz;	//XCLK
    assign JC[4] = clock_25mhz;	//XCLK
    
    //Camera1
    assign JB[2] = SIOC;
    assign JB[0] = SIOD;
    
    //Camera2
    assign JC[0] = SIOC;
    assign JC[1] = SIOD;
    assign VSYNC = (SW[1]) ? JB[4]:JC[2];
    assign HREF = (SW[1]) ? JB[5]:JC[3];
    assign camera_data = (SW[1]) ? JA:JD;

    // BRAM - Write side - PORTA  
    wire [17:0] camera_addra;
    wire [7:0] camera_din;
    wire camera_we;
    // Read side
    reg [17:0] camera_addrb = 0;
    wire [7:0] camera_dout;
    
    // Instantiating BRAM
    
    blk_mem_gen_0 camera_bram(
                    // Port A - Write
                    .addra(camera_addra), .clka(PCLK), .dina(camera_din), .ena(1'b1), .wea(camera_we),
                    // Port B - Read
                    .addrb(camera_addrb), .clkb(clock_25mhz), .enb(1'b1), .doutb(camera_dout)
                    );
    
    // VGA
    reg [3:0] disp_r, disp_g, disp_b; 
    reg red_done;
    wire displaying;
    
    wire [7:0] BW_THRESHOLD = 8'h10;
    wire [7:0] TRACK_CAMERA_THRESHOLD = SW[15:8];
    
    camera_read camera1(.clock_25mhz(clock_25mhz), .start(BTNC), .camera_data(camera_data),
                        .PCLK(PCLK), .VSYNC(VSYNC), .HREF(HREF), .bram_addr(camera_addra),
                        .bram_din(camera_din), .bram_we(camera_we), .threshold_on(1'b1),
                        .threshold(BW_THRESHOLD), .SIOC(SIOC), .SIOD(SIOD));
    
    wire [9:0] hcount;
    wire [9:0] vcount;
    wire hsync_disp, vsync_disp, at_display_area;
    
    vga vga1(.vga_clock(clock_25mhz),.hcount(hcount),.vcount(vcount),
          .hsync(hsync_disp),.vsync(vsync_disp),.at_display_area(at_display_area));

    reg first_byte = 1;
    
    wire [9:0] last_com_x1, last_com_x2;
    wire [9:0] last_com_y1, last_com_y2;

    com_finder dot_tracker(.clock(clock_25mhz), .first_byte(first_byte), .hcount(hcount), .vcount(vcount),
                            .vsync_disp(vsync_disp), .camera_dout(camera_dout), .last_com_x1(last_com_x1),
                            .last_com_y1(last_com_y1), .last_com_x2(last_com_x2), .last_com_y2(last_com_y2));
    
    wire [9:0] current_x, current_y;
    wire [10:0] next_x, next_y;
    
    location_heading_calculator location_heading(.clock(clock_25mhz), .vsync_disp(vsync_disp),
            .last_com_x1(last_com_x1), .last_com_y1(last_com_y1), .last_com_x2(last_com_x2),
            .last_com_y2(last_com_y2), .current_x(current_x), .current_y(current_y),
            .next_x(next_x), .next_y(next_y));
            
    //CAR CONTROLLER STUFF//
    wire foward_ctrl = 0;
    wire backward_ctrl = 0;
    wire left_ctrl = 0;
    wire right_ctrl = 0;
    wire toggle_autonomous = BTND;
    wire reset = ~CPU_RESETN;
    wire new_region_request;
    wire manual_control = 0;
    wire [1:0] car_region;
    wire [1:0] next_region;
    wire [3:0] state;

    car_controller car_controller(.clk(clock_25mhz), 
                            .reset(reset), //FPGA reset
                            .manual_control(manual_control), // enable manual control
                            .foward_in(foward_ctrl), // button that controls foward motion
                            .backward_in(backward_ctrl), // button that controls backward motion
                            .left_in(left_ctrl), // button that controls left turns
                            .right_in(right_ctrl), // button that controls right turns
                            .toggle_autonomous(toggle_autonomous), // enables autonomous driving
                            .car_region(next_region), //
                            .next_region(car_region), //
                            .foward_out(JD[0]), // output that controls foward motion
                            .backward_out(JD[1]), // output that controls backward motion
                            .left_out(JD[2]), // output that controls left turns
                            .right_out(JD[3]), // output that controls right turns
                            .new_region(new_region_request),
                            .state(state));

    assign LED16_B = new_region_request;
    assign LED17_R = state[0];
    assign LED17_G = state[1];
    assign LED17_B = state[2];
    
    wire [17:0] track_read_addr_recog;
    wire rec_track_done;
    reg [17:0] track_read_addr_disp;
    wire [17:0] track_read_addr = (rec_track_done) ? track_read_addr_disp : track_read_addr_recog; 
    wire [7:0] track_data;
    
    wire [17:0] track_addra;
    wire [7:0] track_din;
    wire track_write_clock, track_we;
    
    blk_mem_gen_0 track_bram(
                            // Port A - Write
                            .addra(track_addra), .clka(track_write_clock), .dina(track_din), .ena(1'b1), .wea(track_we),
                            // Port B - Read
                            .addrb(track_read_addr), .clkb(clock_25mhz), .enb(1'b1), .doutb(track_data)
                            );

    wire [17:0] region_write_addr;
    wire [17:0] region_read_addr;
    wire [7:0]  region_din, region_dout;
    wire region_we;
    
    blk_mem_gen_0 region_bram(
        // Port A - Write
        .addra(region_write_addr), .clka(clock_25mhz), .dina(region_din), .ena(1'b1), .wea(region_we),
        // Port B - Read
        .addrb(region_read_addr), .clkb(clock_25mhz), .enb(1'b1), .doutb(region_dout)
        );

    //REGION REPORTING//
    //INSERT BRAM HERE ALONG WITH RELEVANT BRAMSHIT//
    
    region_manager region_manager(.clk(clock_25mhz), .current_x(current_x), .current_y(current_y), .next_x(next_x),
                                    .next_y(next_y), .region_data(region_dout), .new_region_request(new_region_request),
                                    .reset(reset), .region_addr(region_read_addr), .out_car_region(car_region),
                                    .out_next_region(next_region));
                                    
//assign region_read_addr = track_read_addr_disp; // WARNING: REMOVE

    track_recognizer track_recognition(
         .clock_25mhz(clock_25mhz), 
         .start(BTNU),
         .camera_data(camera_data),
         .PCLK(PCLK),
         .VSYNC(VSYNC),
         .HREF(HREF),
         .threshold(TRACK_CAMERA_THRESHOLD),
         
         // BRAM IOs - region bram
         .region_write_addr(region_write_addr),
         .region_din(region_din),
         .region_we(region_we),
         
         // BRAM IOs
         .bram_write_addr(track_addra),
         .bram_write_clock(track_write_clock),
         .bram_din(track_din),
         .bram_we(track_we),
         .bram_read_addr(track_read_addr_recog),
         .bram_read_out(track_data),
         
         // Following is used for debug purpose
         .hcount(hcount),
         .vcount(vcount),
         .disp_r(track_disp_r), 
         .disp_g(track_disp_g), 
         .disp_b(track_disp_b),
         .disp_switch(SW[6]),
         .stop_filter_switch(SW[7]),
         .done(rec_track_done) 
          );
    
    reg drive = 0;
    
    always @(posedge clock_25mhz) begin
        // Display VGA module if software switch is turned on
        if (SW[0]) begin 
            disp_r <= {4{hcount[7]}};
            disp_g <= {4{hcount[6]}};
            disp_b <= {4{hcount[5]}};
            
        end else if (SW[2] & ~SW[3]) begin
            first_byte <= ~first_byte;
            if(at_display_area) camera_addrb <= ((vcount-35)*640 + hcount-142)>>1;
            else camera_addrb <= 0;
            
            if (first_byte == 1) begin
                disp_r <= camera_dout[7:4]; 
                disp_g <= camera_dout[7:4];
                disp_b <= camera_dout[7:4];
            end else if (first_byte == 0) begin
                disp_r <= camera_dout[3:0]; 
                disp_g <= camera_dout[3:0];
                disp_b <= camera_dout[3:0];
            end
            
        end else if ((SW[3]&drive) | BTND) begin
            drive <= 1;
            first_byte <= ~first_byte;
            if(at_display_area) camera_addrb <= ((vcount-35)*640 + hcount-142)>>1;
            else camera_addrb <= 0;
            track_read_addr_disp <= ((vcount-35)*640 + hcount-142)>>1;
            
            if ((hcount == last_com_x1+144 & vcount == last_com_y1+35)|(hcount == last_com_x2+144 & vcount == last_com_y2+35)) begin
                disp_r <= 4'hF;
                disp_g <= 4'hF;
                disp_b <= 4'hF;
            end else if ((hcount == current_x + 144)|(vcount == current_y + 35)) begin
                disp_r <= 0;
                disp_g <= 4'hF;
                disp_b <= 0;
            end else if ((hcount == next_x+144)|(vcount == next_y + 35)) begin
                disp_r <= 0;
                disp_g <= 0;
                disp_b <= 4'hF;     
            end else begin
                disp_r <= track_data[7:4];
                disp_g <= track_data[7:4];
                disp_b <= track_data[7:4];
            end
        end else if ((~SW[3]&~drive) | BTNU) begin
            drive <= 0;
            if (rec_track_done) begin
                first_byte <= ~first_byte;
                track_read_addr_disp <= ((vcount-35)*640 + hcount-142)>>1;
                // Show Recognized track
                
//                disp_r <= region_dout[7:4];
//                disp_g <= region_dout[7:4];
//                disp_b <= region_dout[7:4];
                
//                  if (region_dout[7:4] == 0) begin
//                       disp_r <= 4'hF; 
//                       disp_g <= 0;
//                       disp_b <= 0;
//                   end else if (region_dout[7:4] == 1) begin
//                       disp_r <= 0; 
//                       disp_g <= 4'hF;
//                       disp_b <= 0;
//                   end else if (region_dout[7:4] == 2) begin
//                       disp_r <= 0; 
//                       disp_g <= 0;
//                       disp_b <= 4'hF;
//                   end
//               end
                                
                disp_r <= track_data[7:4];
                disp_g <= track_data[7:4];
                disp_b <= track_data[7:4];
                
//                if ((hcount == last_com_x1+144 & vcount == last_com_y1+35)|(hcount == last_com_x2+144 & vcount == last_com_y2+35)) begin
//                    disp_r <= 4'hF;
//                    disp_g <= 4'hF;
//                    disp_b <= 4'hF;
//                end else if ((hcount == current_x + 144)|(vcount == current_y + 35)) begin
//                    disp_r <= 0;
//                    disp_g <= 4'hF;
//                    disp_b <= 0;
//                end else if ((hcount == next_x+144)|(vcount == next_y + 35)) begin
//                    disp_r <= 0;
//                    disp_g <= 0;
//                    disp_b <= 4'hF;    
//                end 
   
            
            end else begin
                disp_r <= 0;
                disp_g <= 4'hF;
                disp_b <= 0;
            end 
        end
    end
        
    assign VGA_R = at_display_area ? disp_r : 0;
    assign VGA_G = at_display_area ? disp_g : 0;
    assign VGA_B = at_display_area ? disp_b : 0;
    assign VGA_HS = ~hsync_disp;
    assign VGA_VS = ~vsync_disp;
    
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
