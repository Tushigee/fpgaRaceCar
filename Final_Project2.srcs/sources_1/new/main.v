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
    input BTNU,
    input [7:0] JA,
    input[15:0] SW, 
    inout [7:0] JB,
    output [3:0] VGA_R, 
    output [3:0] VGA_B,
    output [3:0] VGA_G,
    output VGA_HS, 
    output VGA_VS,
    output[7:0] SEG,  // segments A-G (0-6), DP (7)
    output[15:0] LED,
    output[7:0] AN,    // Display 0-7
    output [7:0] JD, JC
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
    
    reg [15:0] status_y;
    
    assign data = {JA, intense_byte, intense_byte1};
//    assign data = {6'h0, hcount, 6'h0, vcount};    
    wire SIOD;
    wire SIOC;
    wire PCLK;
//    wire XCLK;
    wire VSYNC;
    wire HREF;
    wire RESET;
    wire PWDN;
    
    // For debug purpose
    
    assign JD[0] =  PCLK;
    assign JD[1] =  HREF;
    assign JD[2] = VSYNC;
    assign JD[3] = status;
    
    assign PCLK = JB[7];
    assign VSYNC = JB[4];
    assign HREF = JB[5];

    assign JB[0] = SIOD;
    assign JB[2] = SIOC;
    assign JB[3] = clock_25mhz;
    assign JB[6] = RESET;
    assign JB[1] = PWDN;
    assign RESET = 1;
    assign PWDN = 0;
    
    // Camera Module
    wire config_done;
    camera_configure OV7670_config(.clk(clock_25mhz), .start(BTNC), .sioc(SIOC), .siod(SIOD), .done(config_done));
    assign LED[15] = config_done;
    reg [1:0] byte_counter = 0;
    reg [7:0] intense_byte, intense_byte1, u, v;
    reg vsync_prev;
    
    // FSM/BRAM
    localparam WAITING = 0;
    localparam RECORD = 1;
    reg status = WAITING;
    
    // BRAM - Write side - PORTA  
    reg [17:0] addra = 0;
    reg [15:0] din = 0;
    reg we = 0;
    reg write_done = 0;
    // Read side
    reg [17:0] addrb = 0;
    wire [15:0] dout;
    
    // Instiniating BRAM
    
    blk_mem_gen_0 bram(
                    // Port A - Write
                    .addra(addra), .clka(PCLK), .dina(din), .ena(1'b1), .wea(we),
                    // Port B - Read
                    .addrb(addrb), .clkb(clock_25mhz), .enb(1'b1), .doutb(dout)
                    );
    
    // VGA
    reg [3:0] disp_r, disp_g, disp_b; 
    reg red_done;
    wire displaying;
    assign displaying = SW[15];
    
    localparam BW_THRESHOLD = 8'hC0;
    
    always @ (posedge PCLK) begin
        vsync_prev <= VSYNC;
        // Write all Blue to BRAM
        if (SW[4]) begin 
            addra <= addra + 1;
            if(addra == 153600) begin
                red_done <= 1;
                we <= 0;
                if (SW[5] == 1) addra <= 0;
            end
            
            else begin
                we <= 1;
                // All blue s 
                din <= 16'h000F;
            end
        end 
        else if (SW[2]) begin
            if (SW[3]) begin 
                addra <= 0;
                write_done <= 0;
            end else begin
                if (addra == 153600) begin
                    write_done <= 1;
                    addra <= 0;
                    status <= WAITING;
                end else begin
                    write_done <= 0;
                    case(status)
                        WAITING: begin
                            if (VSYNC == 0 & vsync_prev == 1) status <= RECORD;
                        end
                        // Made BRAM to hold two pixels at the same time
                        RECORD: begin
                            if (VSYNC == 1) status <= WAITING;
                            else if (HREF == 1) begin    // possible issues with byte_counter not resetting
                                byte_counter <= byte_counter + 1;
                                case(byte_counter)
                                    0: begin    // Write two values we stored
                                        we <= 1;
                                        u <= JA;
                                        addra <= addra + 1;
                                        din <= {intense_byte, intense_byte1};
                                    end
                                    1: begin
                                        if (SW[5] == 1) intense_byte <= JA;
                                        else if(JA>BW_THRESHOLD) intense_byte <= 8'hFF;
                                        else intense_byte <= 0;
                                        we <= 0;
                                    end 
                                    2: begin
                                        v <= JA;
                                    end
                                    3: begin
                                        if (SW[5] == 1) intense_byte1 <= JA; 
                                        else if(JA>BW_THRESHOLD) intense_byte1 <= 8'hFF;
                                        else intense_byte1 <= 0;
                                    end
                                endcase
                            end
                        end
                    endcase
                end
            end
        end 
    end
    assign LED[14] = write_done;
    wire [9:0] hcount;
    wire [9:0] vcount;
    wire hsync_disp, vsync_disp, at_display_area;
    
    vga vga1(.vga_clock(clock_25mhz),.hcount(hcount),.vcount(vcount),
          .hsync(hsync_disp),.vsync(vsync_disp),.at_display_area(at_display_area));

    reg first_byte = 1;

    always @(posedge clock_25mhz) begin
        // Display VGA module if software switch is turned on
        if (SW[0]) begin 
            disp_r <= {4{hcount[7]}};
            disp_g <= {4{hcount[6]}};
            disp_b <= {4{hcount[5]}};
        end else if (SW[4] & red_done) begin 
            // Read from BRAM should display red
            addrb <= ((vcount-35)*480 + hcount-144)>>2;
            disp_r <= dout[3:0]; 
            disp_g <= dout[7:4];
            disp_b <= dout[11:8];
        end else if (SW[2]) begin
            status_y <= dout;
            first_byte <= ~first_byte;
            if(at_display_area) addrb <= ((vcount-35)*640 + hcount-144)>>1;
            else addrb <= 0;
            
            if (first_byte == 0) begin
                disp_r <= dout[7:4]; 
                disp_g <= dout[7:4];
                disp_b <= dout[7:4];
            end else if (first_byte == 1) begin
                disp_r <= dout[15:12]; 
                disp_g <= dout[15:12];
                disp_b <= dout[15:12];
            end
//            if (hcount == 784 & vcount == 515) displaying <= 0;
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