`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2015 03:47:36 PM
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
    input BTNC,
    input [7:0] JA,
    input[15:0] SW, 
    inout [7:0] JB,
    output [3:0] VGA_R, VGA_B, VGA_G,
    output VGA_HS, 
    output VGA_VS,
    output[7:0] SEG,  // segments A-G (0-6), DP (7)
    output[15:0] LED,
    output[7:0] AN,    // Display 0-7
    output [7:0] JD, JC
    );
    
    assign LED = SW;  
    
    wire clock_25mhz;
    clock_quarter_divider clockgen(.clk100_mhz(CLK100MHZ), .clock_25mhz(clock_25mhz));

//  instantiate 7-segment display;  
    wire [31:0] data;
    wire [6:0] segments;
    reg [15:0] camera_rgb_disp;
    display_8hex display(.clk(clock_25mhz), .data(data), .seg(segments), .strobe(AN));    
    assign SEG[6:0] = segments;
    assign SEG[7] = 1'b1;
    assign data = {camera_rgb_disp, 14'h0, status};    
    
    wire SIOD;
    wire SIOC;
    wire PCLK;
//    wire XCLK;
    wire VSYNC;
    wire HREF;
    wire RESET;
    wire PWDN;

    assign PCLK = JB[1];
    assign VSYNC = JB[4];
    assign HREF = JB[5];

    assign JB[0] = SIOD;
    assign JB[2] = SIOC;
    assign JB[3] = clock_25mhz;
    assign JB[6] = RESET;
    assign JB[7] = PWDN;
        
    // create 25mhz system clock
    
    assign RESET = 1;
    assign PWDN = 0;
    
    wire config_done;
    wire [15:0] pixel_data;
    wire pixel_valid;
    wire frame_done;
    
    camera_configure OV7670_config(.clk(clock_25mhz), .start(BTNC), .sioc(SIOC), .siod(SIOD), .done(config_done));
    
    camera_read OV7670_reading(.p_clock(PCLK), .vsync(VSYNC), .href(HREF), .p_data(JA), .pixel_data(pixel_data), .pixel_valid(pixel_valid), .frame_done(frame_done));
    
    wire [9:0] hcount = 0;
    wire [9:0] vcount = 0;
    wire display_hsync, display_vsync, at_display_area;
    
    vga vga1(.vga_clock(clock_25mhz),.hcount(hcount),.vcount(vcount),
              .hsync(display_hsync),.vsync(display_vsync),.at_display_area(at_display_area));
    
    reg [3:0] display_r, display_g, display_b;
            
    assign VGA_HS = ~display_hsync;
    assign VGA_VS = ~display_vsync;
    
    assign VGA_R = display_r;
    assign VGA_G = display_g;
    assign VGA_B = display_b;
 
    reg we = 0;
    reg [16:0] addr;
    reg [15:0] din;
    wire [15:0] dout;
    
    blk_mem_gen_0 bram(.clka(clock_25mhz),
                        // Enabling read write operations for the  
                        .ena(1'b1), 
                        .wea(we),
                        .addra(addr),
                        .dina(din),
                        .douta(dout));
    
    parameter WAITING = 0;
    parameter READING = 1;
    parameter DISPLAYING = 2;
    
    reg every_other = 0;
    
    reg [1:0] status = WAITING;
                        
    always @ (posedge clock_25mhz) begin
        if (config_done) begin
            case(status)
                WAITING: begin
                    if (VSYNC) status <= WAITING;
                    else begin
                        status <= READING;
                        addr <= 0;
                    end
                end
                READING: begin
                    if(pixel_valid) begin
                        every_other <= ~every_other;
                        if(every_other) begin
                            we <= 1;
                            addr <= addr + 1;
                            din <= pixel_data;
                        end
                        else we <= 0;
                    end
                    if(VSYNC) begin
                        status <= DISPLAYING;
                        we <= 0;
                    end
                end
                DISPLAYING: begin
                    addr <= (vcount -1)*480 + hcount;
    //                display_r <= dout[15:12];
    //                display_g <= dout[10:7];
    //                display_b <= dout[4:1];
                    display_r <= 4'h0;
                    display_g <= 4'hF;
                    display_b <= 4'h0;
                    camera_rgb_disp <= addr;
                    // if (~display_vsync) status <= WAITING;
                end 
            endcase
        end
        else status <= WAITING; // config_done is reset
     end 
    
    assign JD[7] = clock_25mhz;
    assign JC[0] = config_done;
     
endmodule

module vga(input vga_clock,
            output reg [9:0] hcount,    // pixel number on current line
            output reg [9:0] vcount,	 // line number
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

module clock_quarter_divider(input clk100_mhz, output reg clock_25mhz = 0);
    reg counter = 0;
    
    always @(posedge clk100_mhz) begin
        counter <= counter + 1;
        if (counter == 0) begin
            clock_25mhz <= ~clock_25mhz;
        end
    end
endmodule

module display_8hex(
    input clk,                 // system clock
    input [31:0] data,         // 8 hex numbers, msb first
    output reg [6:0] seg,      // seven segment display output
    output reg [7:0] strobe    // digit strobe
    );

    localparam bits = 13;
     
    reg [bits:0] counter = 0;  // clear on power up
     
    wire [6:0] segments[15:0]; // 16 7 bit memorys
    assign segments[0]  = 7'b100_0000;
    assign segments[1]  = 7'b111_1001;
    assign segments[2]  = 7'b010_0100;
    assign segments[3]  = 7'b011_0000;
    assign segments[4]  = 7'b001_1001;
    assign segments[5]  = 7'b001_0010;
    assign segments[6]  = 7'b000_0010;
    assign segments[7]  = 7'b111_1000;
    assign segments[8]  = 7'b000_0000;
    assign segments[9]  = 7'b001_1000;
    assign segments[10] = 7'b000_1000;
    assign segments[11] = 7'b000_0011;
    assign segments[12] = 7'b010_0111;
    assign segments[13] = 7'b010_0001;
    assign segments[14] = 7'b000_0110;
    assign segments[15] = 7'b000_1110;
     
    always @(posedge clk) begin
      counter <= counter + 1;
      case (counter[bits:bits-2])
          3'b000: begin
                  seg <= segments[data[31:28]];
                  strobe <= 8'b0111_1111 ;
                 end

          3'b001: begin
                  seg <= segments[data[27:24]];
                  strobe <= 8'b1011_1111 ;
                 end

          3'b010: begin
                   seg <= segments[data[23:20]];
                   strobe <= 8'b1101_1111 ;
                  end
          3'b011: begin
                  seg <= segments[data[19:16]];
                  strobe <= 8'b1110_1111;        
                 end
          3'b100: begin
                  seg <= segments[data[15:12]];
                  strobe <= 8'b1111_0111;
                 end

          3'b101: begin
                  seg <= segments[data[11:8]];
                  strobe <= 8'b1111_1011;
                 end

          3'b110: begin
                   seg <= segments[data[7:4]];
                   strobe <= 8'b1111_1101;
                  end
          3'b111: begin
                  seg <= segments[data[3:0]];
                  strobe <= 8'b1111_1110;
                 end




       endcase
      end

endmodule
