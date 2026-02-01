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
// Last modified Date:     2025/03/20 15:40:03 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/20 15:40:03 
// Version:                V1.0 
// TEXT NAME:              U1_0_2_FIFO_Stack.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U1_0_2_FIFO_Stack.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U1_0_2_FIFO_Stack #(
    parameter                 D_WIDTH                     = 64    ,
    parameter                 D_DEPTH                     = 128   ,
    parameter                 FIFO_CH_NUM                 = 3     
)(
    input                               clk                        ,
    input                               rst                        ,
    
    input                           wr_ena     [FIFO_CH_NUM-1 : 0] ,
    input           [D_WIDTH -1:0]  wr_data    [FIFO_CH_NUM-1 : 0] ,

    output  reg     [    6:0]       fifo_cnt    [FIFO_CH_NUM-1:0],

    input                           rd_ena     [FIFO_CH_NUM-1 : 0] ,
    output  wire    [D_WIDTH -1:0]  rd_data    [FIFO_CH_NUM-1 : 0] 
    

);

    genvar          i       ;

generate
    for (i = 0; i < FIFO_CH_NUM; i = i + 1) begin
            u_Sync_FIFO_FWFT#(
                .DATA_WIDTH                                (D_WIDTH                    ),
                .DATA_DEPTH                                (D_DEPTH                    )
            )
            u_u_Sync_FIFO_FWFT_i(
                .clk                                       (clk                        ),
                .rst                                       (rst                        ),
                .data_in                                   (wr_data[i]                 ),
                .rd_en                                     (rd_ena[i]                  ),
                .wr_en                                     (wr_ena[i]                  ),
                .data_out                                  (rd_data[i]                 ) 
            );
        

        always @(posedge clk ) begin
            if (rst) begin
                fifo_cnt[i]             <=      'b0                 ;
            end else begin
                if (wr_ena[i] & (~rd_ena[i])) begin
                    fifo_cnt[i]         <=      fifo_cnt[i] + 1     ;
                end
                else if (~wr_ena[i] & rd_ena[i]) begin
                    fifo_cnt[i]         <=      fifo_cnt[i] - 1     ;
                end
                else begin
                    fifo_cnt[i]         <=      fifo_cnt[i]         ;
                end
            end
        end

    end
endgenerate


endmodule                                                          
