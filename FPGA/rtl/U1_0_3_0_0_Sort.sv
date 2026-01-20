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
// Last modified Date:     2025/03/20 18:33:07 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/20 18:33:07 
// Version:                V1.0 
// TEXT NAME:              U1_0_3_0_0_Sort.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U1_0_3_0_0_Sort.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U1_0_3_0_0_Sort #(
    parameter                 D_WIDTH                     = 23    ,
    parameter                 CH_NUM                      = 3     
)(
    input                               clk                         ,
    input                               rst                         , 

    input                               src_val                     ,
    input               [D_WIDTH-1:0]   src   [CH_NUM-1:0]          ,
    output  reg         [D_WIDTH-1:0]   sort  [CH_NUM-1:0]          ,
    output  wire                        sort_over_flag                  
    );

    reg                                         sort_over           ;
    reg                       [   1: 0]         val_d               ;
    reg                       [D_WIDTH-1: 0]    tmp1                ;
    reg                       [D_WIDTH-1: 0]    src_2_d             ;
    reg                       [D_WIDTH-1: 0]    unsel0_d            ;
    reg                       [D_WIDTH-1: 0]    unsel1_d            ;
    reg                       [D_WIDTH-1: 0]    tmp_sort            ;

    always @(posedge clk ) 
    begin
        if (rst) begin
            val_d           <=      2'b00                           ;
        end else begin
            val_d[1]        <=      val_d[0]                        ;
            val_d[0]        <=      src_val                         ;
        end
    end

    always @(posedge clk ) 
    begin
        if (rst) begin
            src_2_d         <=      'b0                             ;
        end else begin
            src_2_d         <=      src[2]                          ;
        end
    end

    always @(posedge clk ) 
    begin
        if (rst) begin
            tmp1            <=      'b0                             ;
            unsel0_d        <=      'b0                             ;
        end else begin
            if (src_val) begin
                if (src[1][19:0] < src[0][19:0]) begin
                    tmp1    <=      src[1]                          ;
                    unsel0_d<=      src[0]                          ;
                end else begin
                    tmp1    <=      src[0]                          ;
                    unsel0_d<=      src[1]                          ;
                end
            end else begin
                tmp1        <=      tmp1                            ;
                unsel0_d    <=      unsel0_d                        ;
            end
        end
    end

    always @(posedge clk ) 
    begin
        if (rst) begin
            unsel1_d        <=      'b0                             ;      
        end else begin
            unsel1_d        <=      unsel0_d                        ;
        end
    end

    always @(posedge clk ) 
    begin
        if (rst) begin
            sort[0]         <=      'b0                             ;
            tmp_sort        <=      'b0                             ;
        end else begin
            if (val_d[0]) begin
                if (tmp1[19:0] > src_2_d[19:0]) begin
                    sort[0] <=      src_2_d                         ;
                    tmp_sort<=      tmp1                            ;
                end else begin
                    sort[0] <=      tmp1                            ;
                    tmp_sort<=      src_2_d                         ;
                end
            end else begin
                sort[0]     <=      sort[0]                         ;
                tmp_sort    <=      tmp_sort                        ;
            end
        end
    end

    always @(posedge clk ) 
    begin
        if (rst) begin
            sort[1]         <=      'b0                             ;
            sort[2]         <=      'b0                             ;
            sort_over       <=      'b0                             ;
        end 
        else begin
            if (val_d[1]) begin

                sort_over   <=      val_d[1]                        ;

                if (tmp_sort[19:0] > unsel1_d[19:0]) begin
                    sort[1] <=      unsel1_d                        ;
                    sort[2] <=      tmp_sort                        ;
                end
                else begin
                    sort[2] <=      unsel1_d                        ;
                    sort[1] <=      tmp_sort                        ;
                end
            end 
            else begin
                sort_over   <=      1'b0                            ;
                sort[1]     <=      sort[1]                         ;
                sort[2]     <=      sort[2]                         ;
            end    
        end
    end


    U0_SinglePulse u_U0_SinglePulse(
    .clk                               (clk                        ),
    .rst                               (rst                        ),
    .pos_dir                           (sort_over                  ),
    .pos_pulse                         (sort_over_flag             ) 
    );


endmodule