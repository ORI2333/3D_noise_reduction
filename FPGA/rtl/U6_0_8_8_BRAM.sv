`timescale 1ns / 1ps 
//****************************************VSCODE PLUG-IN**********************************// 
//---------------------------------------------------------------------------------------- 
// IDE :                   VSCODE      
// VSCODE plug-in version: Verilog-Hdl-Format-2.4.20240526
// VSCODE plug-in author : Jiang Percy 
//---------------------------------------------------------------------------------------- 
//****************************************Copyright (c)***********************************// 
// Copyright(C)            COMPANY_NAME
// All rights reserved      
// File name:               
// Last modified Date:     2025/03/18 11:16:56 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/18 11:16:56 
// Version:                V1.0 
// TEXT NAME:              U5_3_BRAM_28port.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U5_3_BRAM_28port.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U6_0_8_8_BRAM#(
    parameter                 ADDR_WIDTH                  = 8     ,
    parameter                 DATA_WIDTH                  = 8     ,
    parameter                 DEPTH                       = 256   ,
    parameter                 CHANNEL                     = 8     
)(
    input                                    clk                  ,
    input                                    rst                  ,

    input                                    we      [CHANNEL-1:0],

    input                  [ADDR_WIDTH-1: 0] wr_addr [CHANNEL-1:0],

    input                  [DATA_WIDTH-1: 0] wr_data [CHANNEL-1:0],

    input                                    re      [CHANNEL-1:0],

    input                  [ADDR_WIDTH-1: 0] rd_addr [CHANNEL-1:0],

    output reg             [DATA_WIDTH-1: 0] rd_data [CHANNEL-1:0]
);


    (*ram_style="block"*) reg [DATA_WIDTH-1:0] bram [DEPTH-1 :0]  ;

    genvar i;

    generate
        for (i = 0; i < CHANNEL; i = i + 1) begin
            always @(posedge clk ) 
            begin
                if (rst) begin
                    rd_data[i] <= 'b0             ; 
                end else if (we[i]) begin
                    bram[wr_addr[i]] <= wr_data[i];
                end else if (re[i]) begin
                    rd_data[i] <= bram[rd_addr[i]];
                end
            end
        end
    endgenerate

endmodule                                                          
