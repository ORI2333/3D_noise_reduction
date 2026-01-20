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
// Last modified Date:     2025/02/17 20:51:31 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/02/17 20:51:31 
// Version:                V1.0 
// TEXT NAME:              U4_MotionEstimate_ThresholdDetect_Subsys.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3D_NoiseReduce\3D_NoiseReduce.srcs\sources_1\imports\3D_Denoise\U4_MotionEstimate_ThresholdDetect_Subsys.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U4_ME_TD_Subsys #(
    parameter                 H_DISP                      = 640   ,
    parameter                 V_DISP                      = 480   ,
    parameter                 CHANNEL_NUM                 = 8     ,
    parameter                 MACRO_BLOCK_THRESHOLD       = 0     
)(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       start                       ,

    input                     [  14: 0]         proc_block_addr             ,

    output wire                                 rd_ena_wire_R    [CHANNEL_NUM - 1: 0],
    output wire                                 rd_ena_wire_G    [CHANNEL_NUM - 1: 0],
    output wire                                 rd_ena_wire_B    [CHANNEL_NUM - 1: 0],

    output wire               [  15: 0]         rd_addr_wire_R   [CHANNEL_NUM - 1: 0],
    output wire               [  15: 0]         rd_addr_wire_G   [CHANNEL_NUM - 1: 0],
    output wire               [  15: 0]         rd_addr_wire_B   [CHANNEL_NUM - 1: 0],

    output wire               [   1: 0]         rd_type_R        [CHANNEL_NUM - 1: 0],
    output wire               [   1: 0]         rd_type_G        [CHANNEL_NUM - 1: 0],
    output wire               [   1: 0]         rd_type_B        [CHANNEL_NUM - 1: 0],

    input                     [  11: 0]         d_in_R           [CHANNEL_NUM - 1: 0],
    input                     [  11: 0]         d_in_G           [CHANNEL_NUM - 1: 0],
    input                     [  11: 0]         d_in_B           [CHANNEL_NUM - 1: 0],

    output reg                [CHANNEL_NUM-1:0] select_Temporal_R                    ,
    output reg                [CHANNEL_NUM-1:0] select_Temporal_G                    ,
    output reg                [CHANNEL_NUM-1:0] select_Temporal_B                    ,

    output wire                                 ME_TD_finish_flag                    ,
    input                                       finish_clr                 
);

    wire                                        final_info_R [CHANNEL_NUM -1: 0];
    wire                                        final_info_G [CHANNEL_NUM -1: 0];
    wire                                        final_info_B [CHANNEL_NUM -1: 0];


    reg                                         finish_1_0                  ;
    reg                                         finish_2_0                  ;
    reg                                         finish_3_0                  ;
    reg                                         finish_1_1                  ;
    reg                                         finish_2_1                  ;
    reg                                         finish_3_1                  ;


    reg                                         finish_R [CHANNEL_NUM -1: 0];
    reg                                         finish_G [CHANNEL_NUM -1: 0];
    reg                                         finish_B [CHANNEL_NUM -1: 0];

    wire                                        finish_flag  ;

U0_SinglePulse u_U0_SinglePulse(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .pos_dir                                   (finish_flag                ),
    .pos_pulse                                 (ME_TD_finish_flag          ) 
);

    
    assign finish_flag           = finish_1_0 & finish_2_0 & finish_3_0 & finish_1_1 & finish_2_1 & finish_3_1          ;




    always @(posedge clk ) 
    begin
        if (rst) begin
            finish_1_0                      <=               'b0                        ;
            finish_2_0                      <=               'b0                        ;
            finish_3_0                      <=               'b0                        ;
            finish_1_1                      <=               'b0                        ;
            finish_2_1                      <=               'b0                        ;
            finish_3_1                      <=               'b0                        ;
        end else begin
            if (finish_clr) begin
                finish_1_0                  <=              1'b0                        ;
            end
            else if (finish_R[3]&finish_R[2]&finish_R[1]&finish_R[0]) begin
                finish_1_0                  <=              1'b1                        ;
            end else begin
                finish_1_0                  <=          finish_1_0                      ;
            end

            if (finish_clr) begin
                finish_1_1                  <=              1'b0                        ;
            end
            else if (finish_R[7]&finish_R[6]&finish_R[5]&finish_R[4]) begin
                finish_1_1                  <=              1'b1                        ;
            end else begin
                finish_1_1                  <=          finish_1_1                       ;
            end

            if (finish_clr) begin
                finish_2_0                  <=              1'b0                        ;
            end
            else if (finish_G[3]&finish_G[2]&finish_G[1]&finish_G[0]) begin
                finish_2_0                  <=              1'b1                        ;
            end else begin
                finish_2_0                  <=          finish_2_0                        ;
            end

            if (finish_clr) begin
                finish_2_1                  <=              1'b0                        ;
            end
            else if (finish_G[7]&finish_G[6]&finish_G[5]&finish_G[4]) begin
                finish_2_1                  <=              1'b1                        ;
            end else begin
                finish_2_1                  <=          finish_2_1                        ;
            end

            if (finish_clr) begin
                finish_3_0                  <=              1'b0                        ;
            end
            else if (finish_B[3]&finish_B[2]&finish_B[1]&finish_B[0]) begin
                finish_3_0                  <=              1'b1                        ;
            end else begin
                finish_3_0                  <=          finish_3_0                        ;
            end

            if (finish_clr) begin
                finish_3_1                  <=              1'b0                        ;
            end
            else if (finish_B[7]&finish_B[6]&finish_B[5]&finish_B[4]) begin
                finish_3_1                  <=              1'b1                        ;
            end else begin
                finish_3_1                  <=          finish_3_1                        ;
            end

        end
    end


    genvar i;

    wire                      [CHANNEL_NUM-1: 0]         ME_TD_finish_flag_R         ;
    wire                      [CHANNEL_NUM-1: 0]         ME_TD_finish_flag_G         ;
    wire                      [CHANNEL_NUM-1: 0]         ME_TD_finish_flag_B         ;


    generate
        for (i = 0; i < CHANNEL_NUM; i = i + 1) begin
            always @(posedge clk ) begin
                if (rst) begin
                    finish_R[i]              <=              'b0                         ;
                    finish_G[i]              <=              'b0                         ;
                    finish_B[i]              <=              'b0                         ; 
                end 
                else begin
                    if (finish_clr) begin
                        finish_R[i]         <=              'b0                         ;
                    end
                    else if (ME_TD_finish_flag_R[i]) begin
                        finish_R[i]         <=              'b1                         ;
                    end
                    else begin
                        finish_R[i]         <=              finish_R[i]                 ;
                    end    
            
                    if (finish_clr) begin
                        finish_G[i]            <=              'b0                         ;
                    end
                    else if (ME_TD_finish_flag_G[i]) begin
                        finish_G[i]            <=              'b1                         ;
                    end
                    else begin
                        finish_G[i]            <=              finish_G[i]                    ;
                    end      
            
                    if (finish_clr) begin
                        finish_B[i]            <=              'b0                         ;
                    end
                    else if (ME_TD_finish_flag_B[i]) begin
                        finish_B[i]            <=              'b1                         ;
                    end
                    else begin
                        finish_B[i]            <=              finish_B[i]                    ;
                    end       
                end
            end
            
            
            always @(posedge clk ) 
            begin
                if (rst) begin
                    select_Temporal_R[i]       <=              'b0                         ;
                    select_Temporal_G[i]       <=              'b0                         ;
                    select_Temporal_B[i]       <=              'b0                         ;
                end 
                else begin
                    if (finish_clr) begin
                        select_Temporal_R[i]   <=              'b0                         ;
                    end
                    else if (ME_TD_finish_flag_R[i]) begin
                        select_Temporal_R[i]   <=              final_info_R[i]                ;
                    end
                    else begin
                        select_Temporal_R[i]   <=              select_Temporal_R[i]           ;
                    end
            
                    if (finish_clr) begin
                        select_Temporal_G[i]   <=              'b0                         ;
                    end
                    else if (ME_TD_finish_flag_G[i]) begin
                        select_Temporal_G[i]   <=              final_info_G[i]                ;
                    end
                    else begin
                        select_Temporal_G[i]   <=              select_Temporal_G[i]           ;
                    end
            
                    if (finish_clr) begin
                        select_Temporal_B[i]   <=              'b0                         ;
                    end
                    else if (ME_TD_finish_flag_B[i]) begin
                        select_Temporal_B[i]   <=              final_info_B[i]                ;
                    end
                    else begin
                        select_Temporal_B[i]   <=              select_Temporal_B[i]           ;
                    end
                end
            end
        end
    endgenerate


    genvar a;
    generate
        for (a = 0; a < CHANNEL_NUM; a = a + 1) begin
            U4_MotionEstimate_ThresholdDetect #(
                .H_DISP                                    (H_DISP                     ),
                .V_DISP                                    (V_DISP                     ) 
            )u_U4_MotionEstimate_ThresholdDetect_R(
                .clk                                       (clk                        ),
                .rst                                       (rst                        ),

                .start                                     (start                      ),
                .proc_block_addr                           (proc_block_addr + a        ),
                .macro_block_threshold                     (MACRO_BLOCK_THRESHOLD      ),

                .rd_ena_wire                               (rd_ena_wire_R[a]           ),
                .rd_addr_wire                              (rd_addr_wire_R[a]          ),
                .rd_type                                   (rd_type_R[a]               ),// 00 proc 01 match 10 upmatch

                .d_in                                      (d_in_R[a]                  ),

                .select_Temporal                           (final_info_R[a]            ),// 选择时域算法使能信号
                .ME_TD_finish_flag                         (ME_TD_finish_flag_R[a]     ),
                .finish_clr                                (finish_clr                 ) 
            );
            
            U4_MotionEstimate_ThresholdDetect #(
                .H_DISP                                    (H_DISP                     ),
                .V_DISP                                    (V_DISP                     ) 
            )u_U4_MotionEstimate_ThresholdDetect_G(
                .clk                                       (clk                        ),
                .rst                                       (rst                        ),

                .start                                     (start                      ),
                .proc_block_addr                           (proc_block_addr + a        ),
                .macro_block_threshold                     (MACRO_BLOCK_THRESHOLD      ),

                .rd_ena_wire                               (rd_ena_wire_G[a]           ),
                .rd_addr_wire                              (rd_addr_wire_G[a]          ),
                .rd_type                                   (rd_type_G[a]               ),// 你要抽取哪个图像的数�?????? 0原图 1匹配�??????

                .d_in                                      (d_in_G[a]                  ),

                .select_Temporal                           (final_info_G[a]            ),// 选择时域算法使能信号
                .ME_TD_finish_flag                         (ME_TD_finish_flag_G[a]     ),
                .finish_clr                                (finish_clr                 ) 
            );
            
            U4_MotionEstimate_ThresholdDetect #(
                .H_DISP                                    (H_DISP                     ),
                .V_DISP                                    (V_DISP                     ) 
            )u_U4_MotionEstimate_ThresholdDetect_B(
                .clk                                       (clk                        ),
                .rst                                       (rst                        ),

                .start                                     (start                      ),
                .proc_block_addr                           (proc_block_addr + a        ),
                .macro_block_threshold                     (MACRO_BLOCK_THRESHOLD      ),

                .rd_ena_wire                               (rd_ena_wire_B[a]           ),
                .rd_addr_wire                              (rd_addr_wire_B[a]          ),
                .rd_type                                   (rd_type_B[a]               ),// 你要抽取哪个图像的数�?????? 0原图 1匹配�??????

                .d_in                                      (d_in_B[a]                  ),

                .select_Temporal                           (final_info_B[a]            ),// 选择时域算法使能信号
                .ME_TD_finish_flag                         (ME_TD_finish_flag_B[a]     ),
                .finish_clr                                (finish_clr                 ) 
            );
            
        end
    endgenerate



endmodule                                                          
