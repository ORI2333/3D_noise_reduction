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
// Last modified Date:     2025/03/15 10:06:00 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/15 10:06:00 
// Version:                V1.0 
// TEXT NAME:              u_Addr_Map_Subsys.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\u_Addr_Map_Subsys.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module u_Addr_Map_Subsys #(
    parameter                 H_DISP                      = 640   ,
    parameter                 V_DISP                      = 480   ,
    parameter                 CHANNEL_NUM                 = 8     

)(
    input                                       clk                            ,
    input                                       rst                            ,

    input                                       R_rd_ena   [CHANNEL_NUM - 1: 0],
    input                     [   1: 0]         R_rd_type  [CHANNEL_NUM - 1: 0],
    input                     [  15: 0]         R_rd_site  [CHANNEL_NUM - 1: 0],
    output wire               [   1: 0]         R_rd_type_d[CHANNEL_NUM - 1: 0],
    output wire                                 R_rd_ena_d [CHANNEL_NUM - 1: 0],
    output wire               [  14: 0]         R_rd_addr  [CHANNEL_NUM - 1: 0],

    input                                       G_rd_ena   [CHANNEL_NUM - 1: 0],
    input                     [   1: 0]         G_rd_type  [CHANNEL_NUM - 1: 0],
    input                     [  15: 0]         G_rd_site  [CHANNEL_NUM - 1: 0],
    output wire               [   1: 0]         G_rd_type_d[CHANNEL_NUM - 1: 0],
    output wire                                 G_rd_ena_d [CHANNEL_NUM - 1: 0],
    output wire               [  14: 0]         G_rd_addr  [CHANNEL_NUM - 1: 0],

    input                                       B_rd_ena   [CHANNEL_NUM - 1: 0],
    input                     [   1: 0]         B_rd_type  [CHANNEL_NUM - 1: 0],
    input                     [  15: 0]         B_rd_site  [CHANNEL_NUM - 1: 0],
    output wire               [   1: 0]         B_rd_type_d[CHANNEL_NUM - 1: 0],
    output wire                                 B_rd_ena_d [CHANNEL_NUM - 1: 0],
    output wire               [  14: 0]         B_rd_addr  [CHANNEL_NUM - 1: 0] 

);


u_Addr_Map#(
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ),
    .CHANNEL_NUM                               (CHANNEL_NUM                ) 
)
u_u_Addr_Map_R(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .rd_ena                                    (R_rd_ena                   ),
    .rd_type                                   (R_rd_type                  ),
    .rd_site                                   (R_rd_site                  ),
    .rd_type_d                                 (R_rd_type_d                ),
    .rd_ena_d                                  (R_rd_ena_d                 ),
    .rd_addr                                   (R_rd_addr                  ) 
);


u_Addr_Map#(
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ),
    .CHANNEL_NUM                               (CHANNEL_NUM                ) 
)
u_u_Addr_Map_G(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .rd_ena                                    (G_rd_ena                   ),
    .rd_type                                   (G_rd_type                  ),
    .rd_site                                   (G_rd_site                  ),
    .rd_type_d                                 (G_rd_type_d                ),
    .rd_ena_d                                  (G_rd_ena_d                 ),
    .rd_addr                                   (G_rd_addr                  ) 
);


u_Addr_Map#(
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ),
    .CHANNEL_NUM                               (CHANNEL_NUM                ) 
)
u_u_Addr_Map_B(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .rd_ena                                    (B_rd_ena                   ),
    .rd_type                                   (B_rd_type                  ),
    .rd_site                                   (B_rd_site                  ),
    .rd_type_d                                 (B_rd_type_d                ),
    .rd_ena_d                                  (B_rd_ena_d                 ),
    .rd_addr                                   (B_rd_addr                  ) 
);

                                                                   
endmodule                                                          

