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
// Last modified Date:     2025/02/17 18:14:06 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/02/17 18:14:06 
// Version:                V1.0 
// TEXT NAME:              U5_BRAM_Controller_Subsys.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3D_NoiseReduce\3D_NoiseReduce.srcs\sources_1\imports\3D_Denoise\U5_BRAM_Controller_Subsys.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U5_BRAM_Controller_Subsys(
    input                                       clk                         ,
    input                                       rst                         ,
    //---------------------------------------------------------------------------------------
    //                                                                                     
    //---------------------------------------------------------------------------------------
    input                                       prefetch                    ,
    input                                       prefetch_type               ,// 0 为init模式 1为4行读取模式
    input                     [  31: 0]         prefetch_addr    [2:0]      ,
    //---------------------------------------------------------------------------------------
    //                                                                                     
    //---------------------------------------------------------------------------------------
    output wire                                 o_ena_dma_rd                ,//! 本地读请求
    output wire               [  31: 0]         o_addr_dma_rd    [2:0]      ,//! 本地读地址
    output wire               [  31: 0]         o_lenth_dma_rd              ,//! 本地读长度
    input                                       i_finish_dma_rd  [2:0]      ,//! 本地读完成

    //---------------------------------------------------------------------------------------
    //                                                                                     
    //---------------------------------------------------------------------------------------
    input                                       i_wr_MUX_reg_r              ,//1永远指向处理帧
    input                                       i_wr_MUX_reg_g              ,//1永远指向处理帧
    input                                       i_wr_MUX_reg_b              ,//1永远指向处理帧

    input                                       i_wr_MB_ena_r               ,

    input                     [  14: 0]         i_wr_MB_addr_r              ,
    input                     [  11: 0]         i_wr_MB_data_r[1:0]         ,//RGB1 RGB0

    input                                       i_wr_DS_ena_r               ,
    input                     [  12: 0]         i_wr_DS_addr_r              ,
    input                     [  11: 0]         i_wr_DS_data_r              ,
//---------------------------------------------------------------------------------------
//                                                                                     
//---------------------------------------------------------------------------------------

    input                                       i_wr_MB_ena_g               ,

    input                     [  14: 0]         i_wr_MB_addr_g              ,
    input                     [  11: 0]         i_wr_MB_data_g[1:0]         ,//RGB1 RGB0

    input                                       i_wr_DS_ena_g               ,
    input                     [  12: 0]         i_wr_DS_addr_g              ,
    input                     [  11: 0]         i_wr_DS_data_g              ,
//---------------------------------------------------------------------------------------
//                                                                                     
//---------------------------------------------------------------------------------------

    input                                       i_wr_MB_ena_b               ,

    input                     [  14: 0]         i_wr_MB_addr_b              ,
    input                     [  11: 0]         i_wr_MB_data_b[1:0]         ,//RGB1 RGB0

    input                                       i_wr_DS_ena_b               ,
    input                     [  12: 0]         i_wr_DS_addr_b              ,
    input                     [  11: 0]         i_wr_DS_data_b              ,

    //-----------------------------------------------------------------------
    //                                                                       
    //-----------------------------------------------------------------------
    input                                       i_rd_MUX_reg                ,//和wr的控制连接一条通道

    input                     [   1: 0]         i_rd_type_R   [7:0]         ,
    input                     [   1: 0]         i_rd_type_G   [7:0]         ,
    input                     [   1: 0]         i_rd_type_B   [7:0]         ,

    input                                       i_rd_ena_R    [7:0]         ,
    input                                       i_rd_ena_G    [7:0]         ,
    input                                       i_rd_ena_B    [7:0]         ,

    input                     [  14: 0]         i_rd_addr_R   [7:0]         ,
    input                     [  14: 0]         i_rd_addr_G   [7:0]         ,
    input                     [  14: 0]         i_rd_addr_B   [7:0]         ,

    output wire               [  11: 0]         o_rd_data_R   [7:0]         ,
    output wire               [  11: 0]         o_rd_data_G   [7:0]         ,
    output wire               [  11: 0]         o_rd_data_B   [7:0]          

);


genvar i;

generate
    for (i = 0; i < 3; i = i + 1) begin
        U5_BRAM_Prefetch_generator u_U5_BRAM_Prefetch_generator(
            .clk                                       (clk                        ),
            .rst                                       (rst                        ),
        //--------------------------------------------------------------------------
        //
        //--------------------------------------------------------------------------
            .prefetch                                  (prefetch                   ),
            .prefetch_type                             (prefetch_type              ),// 0 为init模式 1为4行读取模式
            .prefetch_addr                             (prefetch_addr[i]           ),
        //--------------------------------------------------------------------------
        //
        //--------------------------------------------------------------------------
            .o_ena_dma_rd_r                            (o_ena_dma_rd               ),// ! 本地读请求
            .o_addr_dma_rd                             (o_addr_dma_rd  [i]         ),// ! 本地读地址
            .o_lenth_dma_rd                            (o_lenth_dma_rd             ),// ! 本地读长度
            .i_finish_dma_rd                           (i_finish_dma_rd[i]         ) // ! 本地读完成
        );
    end
endgenerate





U5_BRAM_Controller u_U5_BRAM_Controller_R(
    .clk                                       (clk                        ),
//-----------------------------------
// Write_Interface
//-----------------------------------
    .i_wr_MUX_reg                              (i_wr_MUX_reg               ),
    .i_wr_MB_ena                               (i_wr_MB_ena_r              ),
    .i_wr_MB_addr                              (i_wr_MB_addr_r             ),
    .i_wr_MB_data                              (i_wr_MB_data_r[1:0]        ),
    .i_wr_DS_ena                               (i_wr_DS_ena_r              ),
    .i_wr_DS_addr                              (i_wr_DS_addr_r             ),
    .i_wr_DS_data                              (i_wr_DS_data_r             ),
//-----------------------------------
// Read_Interface
//-----------------------------------
    .i_rd_MUX_reg                              (i_rd_MUX_reg               ),
    .i_rd_type                                 (i_rd_type_R[7:0]           ),
    .i_rd_ena                                  (i_rd_ena_R[7:0]            ),
    .i_rd_addr                                 (i_rd_addr_R[7:0]           ),
    .o_rd_data                                 (o_rd_data_R[7:0]           ) 
);


U5_BRAM_Controller u_U5_BRAM_Controller_G(
    .clk                                       (clk                        ),
//-----------------------------------
// Write_Interface
//-----------------------------------
    .i_wr_MUX_reg                              (i_wr_MUX_reg               ),
    .i_wr_MB_ena                               (i_wr_MB_ena_g              ),
    .i_wr_MB_addr                              (i_wr_MB_addr_g             ),
    .i_wr_MB_data                              (i_wr_MB_data_g[1:0]        ),
    .i_wr_DS_ena                               (i_wr_DS_ena_g              ),
    .i_wr_DS_addr                              (i_wr_DS_addr_g             ),
    .i_wr_DS_data                              (i_wr_DS_data_g             ),
//-----------------------------------
// Read_Interface
//-----------------------------------
    .i_rd_MUX_reg                              (i_rd_MUX_reg               ),
    .i_rd_type                                 (i_rd_type_G[7:0]           ),
    .i_rd_ena                                  (i_rd_ena_G[7:0]            ),
    .i_rd_addr                                 (i_rd_addr_G[7:0]           ),
    .o_rd_data                                 (o_rd_data_G[7:0]           ) 
);


U5_BRAM_Controller u_U5_BRAM_Controller_B(
    .clk                                       (clk                        ),
//-----------------------------------
// Write_Interface
//-----------------------------------
    .i_wr_MUX_reg                              (i_wr_MUX_reg               ),
    .i_wr_MB_ena                               (i_wr_MB_ena_b              ),
    .i_wr_MB_addr                              (i_wr_MB_addr_b             ),
    .i_wr_MB_data                              (i_wr_MB_data_b[1:0]        ),
    .i_wr_DS_ena                               (i_wr_DS_ena_b              ),
    .i_wr_DS_addr                              (i_wr_DS_addr_b             ),
    .i_wr_DS_data                              (i_wr_DS_data_b             ),
//-----------------------------------
// Read_Interface
//-----------------------------------
    .i_rd_MUX_reg                              (i_rd_MUX_reg               ),
    .i_rd_type                                 (i_rd_type_B[7:0]           ),
    .i_rd_ena                                  (i_rd_ena_B[7:0]            ),
    .i_rd_addr                                 (i_rd_addr_B[7:0]           ),
    .o_rd_data                                 (o_rd_data_B[7:0]           ) 
);



endmodule                                                          
