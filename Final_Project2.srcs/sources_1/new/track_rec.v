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


module camera_read_mod(
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
    input single_frame,
    output reg done = 0
    );
    
    wire config_done;
    
    
    reg [1:0] byte_counter = 0;
    reg [3:0] intense_byte, intense_byte1;
    reg vsync_prev;
    
    // FSM/BRAM
    localparam WAITING = 0;
    localparam RECORD = 1;
    reg status = WAITING;
    
    always @ (posedge PCLK) begin
        vsync_prev <= VSYNC;
        if (start) begin
            bram_addr <= 0;
            status <= WAITING;
            done <= 0;
        end else if (bram_addr == 153600) begin
            bram_addr <= 0;
            status <= WAITING;
            done <= 1;
        end else begin
            case(status)
                WAITING: begin
                    if (VSYNC == 0 & vsync_prev == 1) begin
                        if (single_frame & done) begin
                            status <= WAITING;
                        end else begin 
                            status <= RECORD;
                        end
                    end
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


module filter (input clock_25mhz,
               input reset,
               input [7:0] bram_dout,
               output [17:0] bram_read_addr,
               output reg [17:0] bram_write_addr,
               output reg [7:0]  bram_din,
               output reg bram_we,
               output reg done
                );
        
                localparam START = 0;
                localparam PROCESS = 1;
                localparam TAG_BLACK = 3;
                
                localparam MAX_X = 639;
                localparam MAX_Y = 479;
                localparam MIN_X = 1;
                localparam MIN_Y = 1;
                
                localparam MAX_ADDR = (MAX_X + MAX_Y*640)/2;
                 
                reg [1:0] state;
                reg [1:0] counter = 0;
                reg [10:0] x = MIN_X;
                reg [10:0] y = MIN_Y;
                assign bram_read_addr = (x + y*640) >> 1;
                
                wire isBlack;
                assign isBlack = (bram_dout[7:4] == 4'hF | bram_dout[3:0] == 4'hF);
                      
                always @ (posedge clock_25mhz) begin
                    if (reset) begin
                        state <= START;
                        x <= MIN_X;
                        y <= MIN_Y;
                        bram_we <= 0;
                        bram_din <= 0;
                        done <= 0;
                    end else if (bram_read_addr == MAX_ADDR) begin
                        done <= 1;
                    end 
                    else begin 
        
                        case (state)
                            START: begin
                                state <= PROCESS;  
                                counter <= counter + 1;
                                done <= 0;
                            end
                            PROCESS: begin
                                if (counter == 0) begin
                                    if (x < MAX_X) begin
                                        x <= x + 2;
                                        counter <= counter + 1;
                                        if (isBlack) begin
                                            state <= TAG_BLACK;
                                            bram_we <= 1;
                                            bram_write_addr <= bram_read_addr;
                                            bram_din <= 8'hFF;
                                        end else begin
                                            bram_we <= 0;
                                        end
                                    end
                                    else begin
                                        // GO back to START state since done with reading the frame
                                        x <= MIN_X;
                                        y <= y + 1;
                                        state <= START;
                                        counter <= 0;     
                                        bram_we <= 0;                                    
                                    end
                                end else begin
                                    counter <= counter + 1;
                                    bram_we <= 0;
                                end
                            end
                            TAG_BLACK: begin
                                counter <= counter + 1;
                                if (counter == 0) begin
                                    state <= PROCESS;
                                end else begin
                                    if (x < MAX_X) begin
                                        x <= x + 2;
                                        bram_write_addr <= bram_write_addr + 1;
                                        bram_din <= 8'hFF;
                                        bram_we <= 1;
                                    end else begin
                                        bram_we <= 0; 
                                    end
                                end
                            end
                        endcase
                    end
                end 
endmodule

module track_regionizer (input clock_25mhz,
               input reset,
               input [7:0] bram_dout,
               output [17:0] bram_read_addr,
               output reg [17:0] bram_write_addr,
               output reg [7:0]  bram_din,
               output reg bram_we,
               output reg done
                );
                
                localparam START       = 0;
                localparam START_LEFT  = 1;
                localparam START_RIGHT = 2;
                
                localparam MAX_X = 639;
                localparam MAX_Y = 479;
                localparam MIN_X = 1;
                localparam MIN_Y = 1;
                
                localparam MAX_ADDR = (MAX_X + MAX_Y*640)/2;
                localparam NON_TRACK = 8'b1010_1010; 
                 
                reg [1:0] state;
                reg [1:0] counter = 0;
                reg [10:0] x = MIN_X;
                reg [10:0] y = MIN_Y;
                assign bram_read_addr = (x + y*640) >> 1;
                
                wire isBlack;
                assign isBlack = (bram_dout[7:4] == 4'hF | bram_dout[3:0] == 4'hF);
                
                reg delayed_isBlack = 1;
                
                always @ (posedge clock_25mhz) begin
                    if (reset) begin
                        state <= START;
                        x <= MIN_X;
                        y <= MIN_Y;
                        bram_we <= 0;
                        bram_din <= 0;
                        done <= 0;
                        counter <= 0;
                    end else if (bram_read_addr == MAX_ADDR) begin
                        done <= 1;
                    end 
                    else begin
                        case (state)
                            START: begin
                                state <= START_LEFT;  
                                counter <= counter + 1;
                                done <= 0;
                                x <= MIN_X;
                            end
                            START_LEFT: begin
                                if (counter == 0) begin
                                    if (x < MAX_X) begin
                                        x <= x + 2;
                                        delayed_isBlack <= isBlack;
                                        counter <= counter + 1;
                                        // Transition to start right
                                        if ((delayed_isBlack) & (~isBlack)) begin
                                            state <= START_RIGHT;
                                            x <= MAX_X;
                                            bram_we <= 0;
                                        end else begin
                                            // Write to BRAM that     
                                            bram_we <= 1;
                                            bram_write_addr <= bram_read_addr;
                                            bram_din <= NON_TRACK;
                                        end 
                                    end
                                    else begin
                                        // Complete white line consider next line 
                                        y <= y + 1;
                                        state <= START;
                                        counter <= 0;     
                                        bram_we <= 0;                                    
                                    end
                                end else begin
                                    counter <= counter + 1;
                                    bram_we <= 0;
                                end
                            end
                            START_RIGHT: begin
                                counter <= counter + 1;
                                if (counter == 0) begin
                                    if (x > MIN_X) begin
                                        x <= x - 2;
                                        delayed_isBlack <= isBlack;
                                        counter <= counter + 1;
                                        // Transition to start right
                                        if ((delayed_isBlack) & (~isBlack)) begin
                                            state <= START;
                                            bram_we <= 0;
                                            y <= y + 1;
                                        end else begin
                                            // Write to BRAM that     
                                            bram_we <= 1;
                                            bram_write_addr <= bram_read_addr;
                                            bram_din <= NON_TRACK;
                                        end 
                                    end else begin
                                        // Complete white line consider next line 
                                        y <= y + 1;
                                        state <= START;
                                        counter <= 0;     
                                        bram_we <= 0; 
                                    end 
                                end else begin
                                    bram_we <= 0; 
                                     counter <= counter + 1;
                                end
                            end
                        endcase
                    end
                end 
endmodule

module track_tagger (input clock_25mhz,
               input reset,
               input [7:0] bram_dout,
               output [17:0] bram_read_addr,
               output reg [17:0] bram_write_addr,
               output reg [7:0]  bram_din,
               output reg bram_we,
               output reg done
                );
        
                localparam START = 0;
                localparam PROCESS = 1;
                
                localparam MAX_X = 639;
                localparam MAX_Y = 479;
                localparam MIN_X = 1;
                localparam MIN_Y = 1;
                
                localparam MAX_ADDR = (MAX_X + MAX_Y*640)/2;
                
                localparam OUTSIDE = 0;
                localparam TRACK   = 8'h11;
                localparam INSIDE  = 8'h22;
                         
                reg [1:0] state;
                reg [1:0] counter = 0;
                reg [10:0] x = MIN_X;
                reg [10:0] y = MIN_Y;
                assign bram_read_addr = (x + y*640) >> 1;
                
                wire isBlack, isWhite;
                assign isBlack = (bram_dout[7:4] == 4'h0 | bram_dout[3:0] == 4'h0);
                assign isOutside = (bram_dout[7:4] == 4'b1010 | bram_dout[3:0] == 4'b1010 | x <= 11);
                assign isWhite  =  (~isBlack & ~isOutside);
                       
                always @ (posedge clock_25mhz) begin
                    if (reset) begin
                        state <= START;
                        x <= MIN_X;
                        y <= MIN_Y;
                        bram_we <= 0;
                        bram_din <= 0;
                        done <= 0;
                    end else if (bram_read_addr == MAX_ADDR) begin
                        done <= 1;
                    end 
                    else begin 
                        case (state)
                            START: begin
                                state <= PROCESS;  
                                counter <= counter + 1;
                                done <= 0;
                            end
                            PROCESS: begin
                                if (counter == 0) begin
                                    if (x < MAX_X) begin
                                        x <= x + 2;
                                        counter <= counter + 1;
                                        if (isBlack) begin
                                            bram_we <= 1;
                                            bram_write_addr <= bram_read_addr;
                                            bram_din <= TRACK;
                                        end else if (isOutside) begin
                                            bram_we <= 1;
                                            bram_write_addr <= bram_read_addr;
                                            bram_din <= OUTSIDE;
                                        end else if (isWhite) begin
                                            bram_we <= 1;
                                            bram_write_addr <= bram_read_addr;
                                            bram_din <= INSIDE;
                                        end
                                        else begin
                                            bram_we <= 0;
                                        end
                                    end
                                    else begin
                                        // GO back to START state since done with reading the frame
                                        x <= MIN_X;
                                        y <= y + 1;
                                        state <= START;
                                        counter <= 0;     
                                        bram_we <= 0;                                    
                                    end
                                end else begin
                                    counter <= counter + 1;
                                    bram_we <= 0;
                                end
                            end
                        endcase
                    end
                end 
endmodule


module track_recognizer(input clock_25mhz, 
                   input start,
                   input [7:0] camera_data,
                   input PCLK,
                   input VSYNC,
                   input HREF,
                   input [7:0] threshold,
                   
                   // BRAM region IOs
                   output [17:0] region_write_addr,
                   output [7:0] region_din,
                   output region_we,
                   
                   // BRAM related IOs for scratch pad
                   output [17:0] bram_write_addr,
                   output [17:0] bram_read_addr,
                   
                   input [7:0] bram_read_out,
                   output [7:0] bram_din,
                   output bram_we,
                   output bram_write_clock,
                   
                   // Debug switches
                   input disp_switch,
                   input stop_filter_switch, 
                   
                   // Following is used for debug purpose
                   input [9:0] hcount,
                   input [9:0] vcount,
                   output reg [3:0] disp_r, disp_g, disp_b,
                   output done
                    );
        
        // wire [17:0] bram_write_addr;
        wire [17:0] bram_write_addr_camera;
        wire [17:0] bram_write_addr_filter;
        wire [17:0] bram_write_addr_region;
        wire [17:0] bram_write_addr_tagger;
        
        // wire [17:0] bram_read_addr;
        wire [17:0] bram_read_addr_camera;
        wire [17:0] bram_read_addr_filter;
        wire [17:0] bram_read_addr_region;
        wire [17:0] bram_read_addr_tagger;
        wire [17:0] bram_read_addr_predisp;
        
        // wire [7:0]  bram_din;
        wire [7:0]  bram_din_camera;
        wire [7:0]  bram_din_filter;
        wire [7:0] bram_din_region;
        wire [7:0] bram_din_tagger;
        
        // wire bram_we;
        wire bram_we_camera;
        wire bram_we_filter;  
        wire bram_we_region;
        wire bram_we_tagger;
        
        
        // Instintiating BRAM for 
        
        wire camera_done;
        
        assign bram_write_addr = (camera_done) ? ((filter_done) ? (track_reg_done ? bram_write_addr_tagger : bram_write_addr_region ): bram_write_addr_filter) : bram_write_addr_camera;
        assign bram_read_addr_predisp  = (camera_done) ? ((filter_done) ? (track_reg_done ? bram_read_addr_tagger : bram_read_addr_region) : bram_read_addr_filter) : bram_read_addr_camera; // Change
        assign bram_din        = (camera_done) ? ((filter_done) ? (track_reg_done ? bram_din_tagger : bram_din_region): bram_din_filter) : bram_din_camera;
        assign bram_we         = (camera_done) ? ((filter_done) ? (track_reg_done ? bram_we_tagger : bram_we_region): bram_we_filter) : bram_we_camera;
        assign bram_write_clock = (camera_done) ? clock_25mhz : PCLK;
        
        assign bram_read_addr = bram_read_addr_predisp;
        
        // Instintiating camera module
        camera_read_mod camera_track_recog(.clock_25mhz(clock_25mhz), .start(start), .camera_data(camera_data),
            .PCLK(PCLK), .VSYNC(VSYNC), .HREF(HREF),
            .bram_addr(bram_write_addr_camera), .bram_din(bram_din_camera), .bram_we(bram_we_camera),
            .threshold_on(1'b1), .threshold(threshold),
            .single_frame(1'b1),  // Only takes single frame
            .done(camera_done) // Asserted whenever entire frame is finished
        );
        
        wire neg_camera_done;
        // wire itirator_done;
        assign  neg_camera_done = ~camera_done;

        wire filter_done;
        filter track_filter(.clock_25mhz(clock_25mhz),
                .reset(neg_camera_done),
               .bram_dout(bram_read_out),
               .bram_read_addr(bram_read_addr_filter),
               .bram_write_addr(bram_write_addr_filter),
               .bram_din(bram_din_filter),
               .bram_we(bram_we_filter),
               .done(filter_done)
        );
        wire neg_filter_done;
        assign neg_filter_done = (~filter_done);
        
        wire track_reg_done;
        
        
        track_regionizer track_reg (.clock_25mhz(clock_25mhz),
                          .reset(neg_filter_done),
                          .bram_dout(bram_read_out),
                          .bram_read_addr(bram_read_addr_region),
                          .bram_write_addr(bram_write_addr_region),
                          .bram_din(bram_din_region),
                          .bram_we(bram_we_region),
                          .done(track_reg_done)
                        );
                        
        wire neg_track_reg_done;
        assign neg_track_reg_done = ~track_reg_done;
        
        wire track_tagger_done;
        assign done = track_tagger_done;
        
        track_tagger track_tagger0(.clock_25mhz(clock_25mhz),
                      .reset(neg_track_reg_done),
                      .bram_dout(bram_read_out),
                      .bram_read_addr(bram_read_addr_tagger),
                      .bram_write_addr(region_write_addr),
                      .bram_din(region_din),
                      .bram_we(region_we),
                      .done(track_tagger_done)
                      );
        
    endmodule