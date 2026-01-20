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
// Last modified Date:     2025/03/17 18:18:14 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/17 18:18:14 
// Version:                V1.0 
// TEXT NAME:              U2_0_pixel_add.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U2_0_pixel_add.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U2_1_4p_add #(
    parameter                 DATA_WIDTH                  = 8     
)(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       i_dval                      ,
    input                     [DATA_WIDTH -1: 0]data_in0                    ,
    input                     [DATA_WIDTH -1: 0]data_in1                    ,
    input                     [DATA_WIDTH -1: 0]data_in2                    ,
    input                     [DATA_WIDTH -1: 0]data_in3                    ,

    output   wire             [DATA_WIDTH   : 0]data_out0                   ,
    output   wire             [DATA_WIDTH   : 0]data_out1                   ,
    output   wire                               o_dval                      
);

    reg                       [DATA_WIDTH: 0]         tmp_1      [1:0]      ;
    reg                                               d_val                 ;


always @(posedge clk ) 
begin
    if (rst) begin
        tmp_1[0]                <=              'b0                         ;
        tmp_1[1]                <=              'b0                         ;
    end
    else begin
        if (i_dval) begin
            tmp_1[0]            <=              data_in0 + data_in1         ;
            tmp_1[1]            <=              data_in3 + data_in2         ; 

        end
        else begin
            tmp_1[0]            <=              'b0                         ;
            tmp_1[1]            <=              'b0                         ;
        end
    end
end

always @(posedge clk ) 
begin
    if (rst) begin
        d_val                   <=              'b0                         ;
    end
    else begin
        d_val                   <=              i_dval                      ;
    end
end


    assign  data_out0            =              tmp_1[0]                    ;
    assign  data_out1            =              tmp_1[1]                    ;
    assign  o_dval               =              d_val                       ;

endmodule                                                          
