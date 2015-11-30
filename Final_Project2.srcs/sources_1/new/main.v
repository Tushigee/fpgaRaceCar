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
    input BTNC,
    input [7:0] JA,
    input [15:0] SW, 
    inout [7:0] JB,
    output [3:0] VGA_R, 
    output [3:0] VGA_B,
    output [3:0] VGA_G,
    output VGA_HS, 
    output VGA_VS,
    output[7:0] SEG,  // segments A-G (0-6), DP (7)
    output[15:0] LED,
    output[7:0] AN,    // Display 0-7
    input [7:0] JD,
    inout [7:0] JC
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
    assign data = {6'h0, last_com_x1, 6'h0, last_com_y1};

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
    
    wire [7:0] BW_THRESHOLD = 8'hC0;
    
    camera_read camera1(.clock_25mhz(clock_25mhz), .start(BTNC), .camera_data(camera_data),
                        .PCLK(PCLK), .VSYNC(VSYNC), .HREF(HREF), .bram_addr(camera_addra),
                        .bram_din(camera_din), .bram_we(camera_we), .threshold_on(SW[5]),
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
    
    always @(posedge clock_25mhz) begin
        // Display VGA module if software switch is turned on
        if (SW[0]) begin 
            disp_r <= {4{hcount[7]}};
            disp_g <= {4{hcount[6]}};
            disp_b <= {4{hcount[5]}};
            
        end else if (SW[2] & ~SW[3]) begin
            first_byte <= ~first_byte;
            if(at_display_area) camera_addrb <= ((vcount-35)*640 + hcount-144)>>1;
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
            
        end else if (SW[3]) begin
            first_byte <= ~first_byte;
            if(at_display_area) camera_addrb <= ((vcount-35)*640 + hcount-144)>>1;
            else camera_addrb <= 0;
            
            disp_r <= ((hcount == last_com_x1 & vcount == last_com_y1)|(hcount == last_com_x2 & vcount == last_com_y2)) ? 4'hF:0; 
            disp_g <= ((hcount == last_com_x1 & vcount == last_com_y1)|(hcount == last_com_x2 & vcount == last_com_y2)) ? 4'hF:0;
            disp_b <= ((hcount == last_com_x1 & vcount == last_com_y1)|(hcount == last_com_x2 & vcount == last_com_y2)) ? 4'hF:0;
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
