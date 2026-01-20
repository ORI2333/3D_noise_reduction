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
// Last modified Date:     2025/02/17 20:17:09 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/02/17 20:17:09 
// Version:                V1.0 
// TEXT NAME:              U2_MacroBlock_SubSampling_Subsys.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3D_NoiseReduce\3D_NoiseReduce.srcs\sources_1\imports\3D_Denoise\U2_MacroBlock_SubSampling_Subsys.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U2_MBDS_8CH_Subsys #(
    parameter                 CHANNEL_NUM                 = 8     ,
    parameter                 H_DISP                      = 640   ,
    parameter                 V_DISP                      = 480   
)(
    input                                       clk                         ,
    input                                       rst                         ,

    //-----------------------------------------------------------------------
    // Port_in0                                                                    
    //-----------------------------------------------------------------------

    input                                       R_ena                       ,
    input                                       G_ena                       ,
    input                                       B_ena                       ,

    //-----------------------------------------------------------------------
    // Port_in1                                                               
    //-----------------------------------------------------------------------
    input                                       R_data_valid                ,
    input                     [   7: 0]         R_data_in    [7:0]          ,
    input                                       G_data_valid                ,
    input                     [   7: 0]         G_data_in    [7:0]          ,
    input                                       B_data_valid                ,
    input                     [   7: 0]         B_data_in    [7:0]          ,

    //-----------------------------------------------------------------------
    // Port_out1                                                                    
    //-----------------------------------------------------------------------
    output wire               [  11: 0]         R_MB_dout    [1:0]          ,           
    output wire                                 R_MB_ena                    ,
    output wire               [  11: 0]         B_MB_dout    [1:0]          ,           
    output wire                                 B_MB_ena                    ,
    output wire               [  11: 0]         G_MB_dout    [1:0]          ,           
    output wire                                 G_MB_ena                    ,
    //-----------------------------------------------------------------------
    // Port_out2                                                                    
    //-----------------------------------------------------------------------
    output wire               [  11: 0]         R_Sub_dout                  ,
    output wire                                 R_Sub_ena                   ,
    output wire               [  11: 0]         G_Sub_dout                  ,
    output wire                                 G_Sub_ena                   ,
    output wire               [  11: 0]         B_Sub_dout                  ,
    output wire                                 B_Sub_ena                   ,

    //-----------------------------------------------------------------------
    // Port_out3                                                                    
    //-----------------------------------------------------------------------

    output wire                                 finish_flag                 ,
    input                                       flag_clr                     
);

U0_SinglePulse u_U0_SinglePulse(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .pos_dir                                   (finish_r & finish_g & finish_b),
    .pos_pulse                                 (finish_flag                  ) 
);

    wire                                        R_finish_flag               ;
    wire                                        G_finish_flag               ;
    wire                                        B_finish_flag               ;

    reg                                         finish_r                    ;
    reg                                         finish_g                    ;
    reg                                         finish_b                    ;

    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            finish_r            <=              1'b0                        ;
            finish_g            <=              1'b0                        ;
            finish_b            <=              1'b0                        ;
        end else begin
            if (R_finish_flag) begin
                finish_r        <=              1'b1                        ;
            end else begin
                finish_r        <=              finish_r                    ;    
            end
            
            if (G_finish_flag) begin
                finish_g        <=              1'b1                        ;

            end else begin
                finish_g        <=              finish_g                    ;    
            end
            
            if (B_finish_flag) begin
                finish_b        <=              1'b1                        ;
            end else begin
                finish_b        <=              finish_b                    ;    
            end
        end
    end

U2_MBDS_8CH#(
    .CHANNEL_NUM                               (CHANNEL_NUM                ),
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ) 
)
 u_U2_MBDS_8CH_R(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .ena                                       (R_ena                      ),// !系统启动信号
    .data_valid                                (R_data_valid               ),// !数据有效信号
    .data_in                                   (R_data_in                  ),// !数据输入
    .MB_dout                                   (R_MB_dout                  ),// !宏块数据输出
    .MB_ena                                    (R_MB_ena                   ),// !宏块数据有效
    .Sub_dout                                  (R_Sub_dout                 ),// !下采样数据输�?
    .Sub_ena                                   (R_Sub_ena                  ),// !下采样数据有�?
    .finish_flag                               (R_finish_flag              ),// !一张图处理完成
    .flag_clr                                  (flag_clr                 ) // !清除系统状�?
);


U2_MBDS_8CH#(
    .CHANNEL_NUM                               (CHANNEL_NUM                ),
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ) 
)
u_U2_MBDS_8CH_G(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .ena                                       (G_ena                      ),// !系统启动信号
    .data_valid                                (G_data_valid               ),// !数据有效信号
    .data_in                                   (G_data_in                  ),// !数据输入
    .MB_dout                                   (G_MB_dout                  ),// !宏块数据输出
    .MB_ena                                    (G_MB_ena                   ),// !宏块数据有效
    .Sub_dout                                  (G_Sub_dout                 ),// !下采样数据输�?
    .Sub_ena                                   (G_Sub_ena                  ),// !下采样数据有�?
    .finish_flag                               (G_finish_flag              ),// !一张图处理完成
    .flag_clr                                  (flag_clr                 ) // !清除系统状�?
);


U2_MBDS_8CH#(
    .CHANNEL_NUM                               (CHANNEL_NUM                ),
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ) 
)
u_U2_MBDS_8CH_B(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .ena                                       (B_ena                      ),// !系统启动信号
    .data_valid                                (B_data_valid               ),// !数据有效信号
    .data_in                                   (B_data_in                  ),// !数据输入
    .MB_dout                                   (B_MB_dout                  ),// !宏块数据输出
    .MB_ena                                    (B_MB_ena                   ),// !宏块数据有效
    .Sub_dout                                  (B_Sub_dout                 ),// !下采样数据输�?
    .Sub_ena                                   (B_Sub_ena                  ),// !下采样数据有�?
    .finish_flag                               (B_finish_flag              ),// !一张图处理完成
    .flag_clr                                  (flag_clr                 ) // !清除系统状�?
);


endmodule                                                          
