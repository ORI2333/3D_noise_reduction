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
// Last modified Date:     2025/02/09 16:55:28 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/02/09 16:55:28 
// Version:                V1.0 
// TEXT NAME:              U7_1_0_2_1_LUT_Parameter.v 
// PATH:                   D:\EDA_Work_Space\CCIC_ISP_OV5640\CCIC_ISP_OV5640.srcs\sources_1\new\U7_1_0_2_1_LUT_Parameter.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U6_0_0_0_LUT_Parameter(
    input                               clk                        ,
    input                               rst_n                      ,
    
    input                               ena                        ,
    input              [   7: 0]        din_1                      ,
    input              [   7: 0]        din_2                      ,
    input              [   7: 0]        din_3                      ,
    input              [   7: 0]        din_4                      ,
    input              [   7: 0]        din_5                      ,
    input              [   7: 0]        din_6                      ,
    input              [   7: 0]        din_7                      ,
    input              [   7: 0]        din_8                      ,
    input              [   7: 0]        din_9                      ,

    output wire        [   7: 0]        param_1                    ,
    output wire        [   7: 0]        param_2                    ,
    output wire        [   7: 0]        param_3                    ,
    output wire        [   7: 0]        param_4                    ,
    output wire        [   7: 0]        param_5                    ,
    output wire        [   7: 0]        param_6                    ,
    output wire        [   7: 0]        param_7                    ,
    output wire        [   7: 0]        param_8                    ,
    output wire        [   7: 0]        param_9                    



);



    multi_bram#(
    .ADDR_WIDTH                         (8                         ),
    .DATA_WIDTH                         (8                         ),
    .DEPTH                              (256                       ) 
    )
    u_multi_bram(
    .clk                                (clk                       ),
    .rst                                (~rst_n                    ),

    .re1                                (ena                       ),
    .re2                                (ena                       ),
    .re3                                (ena                       ),
    .re4                                (ena                       ),
    .re5                                (ena                       ),
    .re6                                (ena                       ),
    .re7                                (ena                       ),
    .re8                                (ena                       ),
    .re9                                (ena                       ),
    .rd_addr1                           (din_1                     ),
    .rd_addr2                           (din_2                     ),
    .rd_addr3                           (din_3                     ),
    .rd_addr4                           (din_4                     ),
    .rd_addr5                           (din_5                     ),
    .rd_addr6                           (din_6                     ),
    .rd_addr7                           (din_7                     ),
    .rd_addr8                           (din_8                     ),
    .rd_addr9                           (din_9                     ),

    .rd_data1                           (param_1                   ),
    .rd_data2                           (param_2                   ),
    .rd_data3                           (param_3                   ),
    .rd_data4                           (param_4                   ),
    .rd_data5                           (param_5                   ),
    .rd_data6                           (param_6                   ),
    .rd_data7                           (param_7                   ),
    .rd_data8                           (param_8                   ),
    .rd_data9                           (param_9                   ) 
    );


/*
    U6_0_0_0_0_LUT_ROM LUT_ROM_Value1 (
    .clka                                      (clk                        ),// input wire clka
    .ena                                       (ena                        ),// input wire ena
    .addra                                     (din_1                      ),// input wire [7 : 0] addra
    .douta                                     (param_1                    ),// output wire [7 : 0] douta
    .clkb                                      (clk                        ),// input wire clkb
    .enb                                       (ena                        ),// input wire enb
    .addrb                                     (din_2                      ),// input wire [7 : 0] addrb
    .doutb                                     (param_2                    ) // output wire [7 : 0] doutb
    );

    U6_0_0_0_0_LUT_ROM LUT_ROM_Value2 (
    .clka                                      (clk                        ),// input wire clka
    .ena                                       (ena                        ),// input wire ena
    .addra                                     (din_3                      ),// input wire [7 : 0] addra
    .douta                                     (param_3                    ),// output wire [7 : 0] douta
    .clkb                                      (clk                        ),// input wire clkb
    .enb                                       (ena                        ),// input wire enb
    .addrb                                     (din_4                      ),// input wire [7 : 0] addrb
    .doutb                                     (param_4                    ) // output wire [7 : 0] doutb
    );

    
    U6_0_0_0_0_LUT_ROM LUT_ROM_Value3 (
    .clka                                      (clk                        ),// input wire clka
    .ena                                       (ena                        ),// input wire ena
    .addra                                     (din_5                      ),// input wire [7 : 0] addra
    .douta                                     (param_5                    ),// output wire [7 : 0] douta
    .clkb                                      (clk                        ),// input wire clkb
    .enb                                       (ena                        ),// input wire enb
    .addrb                                     (din_6                      ),// input wire [7 : 0] addrb
    .doutb                                     (param_6                    ) // output wire [7 : 0] doutb
    );

    U6_0_0_0_0_LUT_ROM LUT_ROM_Value4 (
    .clka                                      (clk                        ),// input wire clka
    .ena                                       (ena                        ),// input wire ena
    .addra                                     (din_7                      ),// input wire [7 : 0] addra
    .douta                                     (param_7                    ),// output wire [7 : 0] douta
    .clkb                                      (clk                        ),// input wire clkb
    .enb                                       (ena                        ),// input wire enb
    .addrb                                     (din_8                      ),// input wire [7 : 0] addrb
    .doutb                                     (param_8                    ) // output wire [7 : 0] doutb
    );

    U6_0_0_0_0_LUT_ROM LUT_ROM_Value5 (
    .clka                                      (clk                        ),// input wire clka
    .ena                                       (ena                        ),// input wire ena
    .addra                                     (din_9                      ),// input wire [7 : 0] addra
    .douta                                     (param_9                    ),// output wire [7 : 0] douta
    .clkb                                      (clk                        ),// input wire clkb
    .enb                                       (1'b0                       ),// input wire enb
    .addrb                                     ( 'b0                       ),// input wire [7 : 0] addrb
    .doutb                                     (                           ) // output wire [7 : 0] doutb
    );
*/


endmodule                                                          
