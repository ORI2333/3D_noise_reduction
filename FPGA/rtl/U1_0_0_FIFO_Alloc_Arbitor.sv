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
// Last modified Date:     2025/03/19 21:37:28 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/19 21:37:28 
// Version:                V1.0 
// TEXT NAME:              U1_0_0_FIFO_Alloc_Arbitor.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U1_0_0_FIFO_Alloc_Arbitor.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U1_0_0_FIFO_Alloc_Arbitor(
    input                               clk                        ,
    input                               rst                        ,

    input                               req0                       ,
    input                               req1                       ,
    input                               req2                       ,
    input                 [2:0]         fifo_granted_status        ,

    output   reg                        grant0_d                   ,//表示受理0接口
    output   reg                        grant1_d                   ,//表示受理1接口
    output   reg                        grant2_d                   ,//表示受理2接口
    output   reg                        o_dval_r                   ,
    output   reg          [2:0]         granted_fifo_id   [2:0]    //生成fc的DEMUX寻路逻辑
);

    reg                                         grant0             ;
    reg                                         grant1             ;
    reg                                         grant2             ;
    reg                                         grant_val          ;
    wire                                        fifo_empty         ;
    wire                                        fifo_stay_one      ;
    wire                                        fifo_full          ;

    assign fifo_full     =   fifo_granted_status[0] & fifo_granted_status[1] & fifo_granted_status[2] ;
    assign fifo_empty    = ~(fifo_granted_status[0] | fifo_granted_status[1] | fifo_granted_status[2]);
    assign fifo_stay_two =  (fifo_granted_status[0] ^ fifo_granted_status[1] ^ fifo_granted_status[2]);

    always @(posedge clk ) 
    begin
        if (rst) begin
            grant0          <=          'b0                        ;
            grant1          <=          'b0                        ;
            grant2          <=          'b0                        ;
            grant_val       <=          'b0                        ;
        end 
        else begin
            if (req0 | req1 | req2) begin
                if (fifo_empty) begin
                    grant0  <=          req0                       ;
                    grant1  <=          req1                       ;
                    grant2  <=          req2                       ;
                    grant_val<=         1'b1                       ;
                end 
                else if (fifo_full) begin
                    grant0  <=          'b0                        ;
                    grant1  <=          'b0                        ;
                    grant2  <=          'b0                        ;
                    grant_val<=         1'b1                       ;
                end
                else if (fifo_stay_two) begin
                    grant0  <=          req0                       ;
                    grant1  <=          req1                       ;
                    grant2  <=          req2 & (~(req0 & req1))    ;
                    grant_val<=         1'b1                       ;
                end
                else begin
                    grant0  <=          req0                       ;
                    grant1  <=          req1 & (~req0)             ;
                    grant2  <=          req2 & (~req0) & (~req1)   ;
                    grant_val<=         1'b1                       ;
                end
            end
            else begin
                grant0          <=          'b0                    ;
                grant1          <=          'b0                    ;
                grant2          <=          'b0                    ;
                grant_val       <=          'b0                    ;
            end
        end
    end

    always @(posedge clk ) 
    begin
        if (rst) begin
            grant0_d            <=          'b0                    ;
            grant1_d            <=          'b0                    ;
            grant2_d            <=          'b0                    ;
        end 
        else begin
            grant0_d            <=         grant0                  ;
            grant1_d            <=         grant1                  ;
            grant2_d            <=         grant2                  ;
        end
    end

    always @(posedge clk ) 
    begin
        if (rst) begin
            o_dval_r            <=          'b0                    ;
        end else begin
            if (grant_val) begin
                o_dval_r        <=          1'b1                   ;
            end 
            else begin
                o_dval_r        <=          'b0                    ;
            end
        end
    end

    wire                                   grant_full              ;
    wire                                   grant_two               ;
    wire                                   grant_one               ;
    wire                                   grant_none              ;

    assign grant_full =   grant0 & grant1 & grant2                 ;
    assign grant_none = ~(grant0 | grant1 | grant2)                ;
    assign grant_one  =   grant0 ^ grant1 ^ grant2                 ;

    wire   [2:0]                           pre_grant0              ;
    wire   [2:0]                           pre_grant1              ;
    wire   [2:0]                           pre_grant2              ;

    assign pre_grant0 = (grant0)? (fifo_granted_status[0])? 3'b001 :
                                  (fifo_granted_status[1])? 3'b010 :
                                  (fifo_granted_status[2])? 3'b100 :
                                  3'b000
                        :3'b000;

    assign pre_grant1 = (grant1)? (fifo_granted_status[0])? 3'b001 :
                                  (fifo_granted_status[1])? 3'b010 :
                                  (fifo_granted_status[2])? 3'b100 :
                                  3'b000
                        :3'b000;


    assign pre_grant2 = (grant2)? (fifo_granted_status[0])? 3'b001 :
                                  (fifo_granted_status[1])? 3'b010 :
                                  (fifo_granted_status[2])? 3'b100 :
                                  3'b000
                        :3'b000;

    wire                   [2:0]             map_grant             ;


    assign map_grant = ~{grant0,grant1,grant2};

    wire                                        grant_0_loop       ;
    wire                                        grant_1_loop       ;
    wire                                        grant_2_loop       ;

    assign grant_0_loop = map_grant[0] & (fifo_granted_status[0] | fifo_granted_status[1] | fifo_granted_status[2]) ;
    assign grant_1_loop = map_grant[1] & (fifo_granted_status[0] | fifo_granted_status[1] | fifo_granted_status[2]) ;
    assign grant_2_loop = map_grant[2] & (fifo_granted_status[0] | fifo_granted_status[1] | fifo_granted_status[2]) ;


    always @(posedge clk ) 
    begin
        if (rst) begin
            granted_fifo_id[0]              <=     'b000           ;
            granted_fifo_id[1]              <=     'b000           ;
            granted_fifo_id[2]              <=     'b000           ;
        end 
        else begin
            if (grant_full) begin
                granted_fifo_id[0]          <=    3'b001           ;
                granted_fifo_id[1]          <=    3'b010           ;
                granted_fifo_id[2]          <=    3'b100           ;
            end 
            else if (grant_none) begin
                granted_fifo_id[0]          <=     'b000           ;
                granted_fifo_id[1]          <=     'b000           ;
                granted_fifo_id[2]          <=     'b000           ;
            end
            else if (grant_one) begin
                granted_fifo_id[0]          <=  pre_grant0         ;
                granted_fifo_id[1]          <=  pre_grant1         ;
                granted_fifo_id[2]          <=  pre_grant2         ;
            end
            else begin
                if (grant_0_loop) begin
                    if (fifo_granted_status[0]) begin
                        granted_fifo_id[0]  <=  3'b000             ;
                        granted_fifo_id[1]  <=  3'b010             ;
                        granted_fifo_id[2]  <=  3'b001             ;
                    end 
                    else if (fifo_granted_status[1]) begin
                        granted_fifo_id[0]  <=  3'b000             ;
                        granted_fifo_id[1]  <=  3'b100             ;
                        granted_fifo_id[2]  <=  3'b001             ;
                    end
                    else begin
                        granted_fifo_id[0]  <=  3'b000             ;
                        granted_fifo_id[1]  <=  3'b100             ;
                        granted_fifo_id[2]  <=  3'b010             ;
                    end
                end 
                else if (grant_1_loop) begin
                    if (fifo_granted_status[0]) begin
                        granted_fifo_id[0]  <=  3'b010             ;
                        granted_fifo_id[1]  <=  3'b000             ;
                        granted_fifo_id[2]  <=  3'b001             ;
                    end 
                    else if (fifo_granted_status[1]) begin
                        granted_fifo_id[0]  <=  3'b100             ;
                        granted_fifo_id[1]  <=  3'b000             ;
                        granted_fifo_id[2]  <=  3'b001             ;
                    end
                    else begin
                        granted_fifo_id[0]  <=  3'b100             ;
                        granted_fifo_id[1]  <=  3'b000             ;
                        granted_fifo_id[2]  <=  3'b010             ;
                    end
                end 
                else if (grant_2_loop) begin
                    if (fifo_granted_status[0]) begin
                        granted_fifo_id[0]  <=  3'b010             ;
                        granted_fifo_id[1]  <=  3'b001             ;
                        granted_fifo_id[2]  <=  3'b000             ;
                    end 
                    else if (fifo_granted_status[1]) begin
                        granted_fifo_id[0]  <=  3'b100             ;
                        granted_fifo_id[1]  <=  3'b001             ;
                        granted_fifo_id[2]  <=  3'b000             ;
                    end
                    else begin
                        granted_fifo_id[0]  <=  3'b100             ;
                        granted_fifo_id[1]  <=  3'b010             ;
                        granted_fifo_id[2]  <=  3'b000             ;
                    end
                end
                else begin
                    granted_fifo_id[0]      <= (grant0)? 3'b100:3'b000;
                    granted_fifo_id[1]      <= (grant1)? 3'b010:3'b000;
                    granted_fifo_id[2]      <= (grant2)? 3'b001:3'b000;
                end
            end
        end
    end


endmodule                                                          
