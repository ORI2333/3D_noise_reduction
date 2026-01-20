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

module u_OneHot_1_to_3_DEMUX #(
    parameter                 D_WIDTH                     = 64    ,
    parameter                 CH_NUM                      = 3     
)(
    input                     [CH_NUM - 1: 0]         select_info                 ,

    input                     [D_WIDTH -1: 0]         d_in                        ,
    output                    [D_WIDTH -1: 0]         d_out [CH_NUM -1 : 0]       
);

    genvar i;

    generate
        for (i = 0; i < CH_NUM; i = i + 1) begin
            assign d_out[i] = (select_info[i])?       d_in : 'b0                  ;
        end
    endgenerate

    

endmodule                                                          
