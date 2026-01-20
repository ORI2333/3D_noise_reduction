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
// Last modified Date:     2025/03/20 14:29:53 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/20 14:29:53 
// Version:                V1.0 
// TEXT NAME:              U1_0_1_FC.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U1_0_1_FC.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U1_0_1_FC #(
    parameter                 D_WIDTH                     = 64    ,
    parameter                 FIFO_CH_NUM                 = 3     

)(
    input                                       clk                                       ,
    input                                       rst                                       ,
    
    input                     [   2: 0]         granted_ena                               ,
    input                     [   2: 0]         granted_fifo_id [FIFO_CH_NUM -1: 0]       ,  

    input                     [  63: 0]         M_wr_din        [FIFO_CH_NUM -1: 0]       ,//!写数据输入
    input                                       M_wr_dval       [FIFO_CH_NUM -1: 0]       ,//!写数据有效

    output                    [  63: 0]         S_wr_data       [FIFO_CH_NUM -1: 0]       ,
    output                                      S_wr_dval       [FIFO_CH_NUM -1: 0]       ,

    input                     [  63: 0]         M_rd_din        [FIFO_CH_NUM -1: 0]       ,
    input                                       M_rd_dval       [FIFO_CH_NUM -1: 0]       ,

    output                    [  63: 0]         S_rd_data       [FIFO_CH_NUM -1: 0]       ,
    output                                      S_rd_dval       [FIFO_CH_NUM -1: 0]        

);


    reg                       [   2: 0]         fifo_alloc_mux_r[FIFO_CH_NUM -1: 0]       ;
    wire                      [D_WIDTH -1: 0]   w_tmp_data      [FIFO_CH_NUM -1: 0]       ;
    wire                                        w_tmp_dval      [FIFO_CH_NUM -1: 0]       ;

    wire                      [D_WIDTH -1: 0]   r_tmp_data      [FIFO_CH_NUM -1: 0]       ;
    wire                                        r_tmp_dval      [FIFO_CH_NUM -1: 0]       ;

    genvar i;

    generate

        for (i = 0; i < FIFO_CH_NUM; i = i + 1) begin
            always @(posedge clk ) begin
                if (rst) begin
                    fifo_alloc_mux_r[i]       <=      'b0                       ;
                end
                else begin
                    if (granted_ena[i]) begin
                        fifo_alloc_mux_r[i]   <=      granted_fifo_id[i]        ;
                    end else begin
                        fifo_alloc_mux_r[i]   <=      fifo_alloc_mux_r[i]       ;
                    end
                end
            end
        

        u_OneHot_1_to_3_DEMUX#(
        .D_WIDTH                                   (64                         ),
        .CH_NUM                                    (FIFO_CH_NUM                ) 
        )
        u_u_OneHot_1_to_3_DEMUX_wd0(
        .select_info                               (fifo_alloc_mux_r[i]        ),
        .d_in                                      (M_wr_din[i]                ),
        .d_out                                     (w_tmp_data                 ) 
        );

        u_OneHot_1_to_3_DEMUX#(
        .D_WIDTH                                   (1                          ),
        .CH_NUM                                    (FIFO_CH_NUM                ) 
        )
        u_u_OneHot_1_to_3_DEMUX_wval0(
        .select_info                               (fifo_alloc_mux_r[i]        ),
        .d_in                                      (M_wr_dval[i]               ),
        .d_out                                     (w_tmp_dval                 ) 
        );

        u_OneHot_3_to_1_MUX#(
        .D_WIDTH                                   (64                         ) 
        )
        u_u_OneHot_3_to_1_MUX_wd1(
        .select_info                               ({fifo_alloc_mux_r[2][i],fifo_alloc_mux_r[1][i],fifo_alloc_mux_r[0][i]}),
        .d_in                                      ({w_tmp_data[2],w_tmp_data[1],w_tmp_data[0]}),
        .d_out                                     (S_wr_data[i]               ) 
        );
    
        u_OneHot_3_to_1_MUX#(
        .D_WIDTH                                   (1                          ) 
        )
        u_u_OneHot_3_to_1_MUX0_wval1(
        .select_info                               ({fifo_alloc_mux_r[2][i],fifo_alloc_mux_r[1][i],fifo_alloc_mux_r[0][i]}),
        .d_in                                      ({w_tmp_dval[2],w_tmp_dval[1],w_tmp_dval[0]}),
        .d_out                                     (S_wr_dval[i]               ) 
        );

//-------------------------------------------------------------------------------
//                                                                               
//-------------------------------------------------------------------------------

        u_OneHot_1_to_3_DEMUX#(
        .D_WIDTH                                   (64                         ),
        .CH_NUM                                    (FIFO_CH_NUM                ) 
        )
        u_u_OneHot_1_to_3_DEMUX_d0(
        .select_info                               ({fifo_alloc_mux_r[2][i],fifo_alloc_mux_r[1][i],fifo_alloc_mux_r[0][i]}        ),
        .d_in                                      (M_rd_din[i]                ),
        .d_out                                     (r_tmp_data                 ) 
        );
    
        u_OneHot_1_to_3_DEMUX#(
        .D_WIDTH                                   (1                          ),
        .CH_NUM                                    (FIFO_CH_NUM                ) 
        )
        u_u_OneHot_1_to_3_DEMUX_val0(
        .select_info                               ({fifo_alloc_mux_r[2][i],fifo_alloc_mux_r[1][i],fifo_alloc_mux_r[0][i]}),
        .d_in                                      (M_rd_dval[i]               ),
        .d_out                                     (r_tmp_dval                 ) 
        );

        u_OneHot_3_to_1_MUX#(
        .D_WIDTH                                   (64                         ) 
        )
        u_u_OneHot_3_to_1_MUX_d1(
        .select_info                               (fifo_alloc_mux_r[i]        ),
        .d_in                                      ({r_tmp_data[2],r_tmp_data[1],r_tmp_data[0]}),
        .d_out                                     (S_rd_data[i]               ) 
        );

        u_OneHot_3_to_1_MUX#(
        .D_WIDTH                                   (1                          ) 
        )
        u_u_OneHot_3_to_1_MUX_val1(
        .select_info                               (fifo_alloc_mux_r[i]        ),
        .d_in                                      ({r_tmp_dval[2],r_tmp_dval[1],r_tmp_dval[0]}),
        .d_out                                     (S_rd_dval[i]               ) 
        );

        end
    endgenerate





endmodule                                                          
