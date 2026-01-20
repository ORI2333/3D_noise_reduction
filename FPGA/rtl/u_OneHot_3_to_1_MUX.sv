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
// Last modified Date:     2025/03/20 14:49:47 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/20 14:49:47 
// Version:                V1.0 
// TEXT NAME:              u_OneHot_1_to_3_DEMUX.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\u_OneHot_1_to_3_DEMUX.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module u_OneHot_3_to_1_MUX #(
    parameter                  D_WIDTH              = 64                          ,
    parameter                 FIFO_CH_NUM           = 3     
)(
    input                     [FIFO_CH_NUM-1: 0]      select_info                 ,
    input                     [D_WIDTH -1: 0]         d_in       [FIFO_CH_NUM-1:0],
    output wire               [D_WIDTH -1: 0]         d_out                       
);

    assign d_out =               (select_info[0])? d_in[0]
                                :(select_info[1])? d_in[1] 
                                :(select_info[2])? d_in[2]
                                :d_in[0];

endmodule                                                          
