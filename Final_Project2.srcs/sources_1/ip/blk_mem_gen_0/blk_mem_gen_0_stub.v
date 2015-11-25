// Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2014.4.1 (lin64) Build 1149489 Thu Feb 19 16:01:47 MST 2015
// Date        : Tue Nov 24 15:31:53 2015
// Host        : eecs-digital-34 running 64-bit Ubuntu 12.04.5 LTS
// Command     : write_verilog -force -mode synth_stub
//               /afs/athena.mit.edu/user/k/s/kschan/Documents/6.111/Final_Project2/Final_Project2.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0_stub.v
// Design      : blk_mem_gen_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-3
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_2,Vivado 2014.4.1" *)
module blk_mem_gen_0(clka, ena, wea, addra, dina, clkb, enb, addrb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,ena,wea[0:0],addra[17:0],dina[7:0],clkb,enb,addrb[17:0],doutb[7:0]" */;
  input clka;
  input ena;
  input [0:0]wea;
  input [17:0]addra;
  input [7:0]dina;
  input clkb;
  input enb;
  input [17:0]addrb;
  output [7:0]doutb;
endmodule
