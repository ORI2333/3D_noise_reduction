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
// Last modified Date:     2025/02/17 17:42:15 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/02/17 17:42:15 
// Version:                V1.0 
// TEXT NAME:              U0_SinglePulse_SubSys.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3D_NoiseReduce\3D_NoiseReduce.srcs\sources_1\imports\3D_Denoise\U0_SinglePulse_SubSys.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U0_SinglePulse_SubSys(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       pos_dir0                    ,
    input                                       pos_dir1                    ,
    input                                       pos_dir2                    ,
    input                                       pos_dir3                    ,
    input                                       pos_dir4                    ,
    input                                       pos_dir5                    ,
    input                                       pos_dir6                    ,
    input                                       pos_dir7                    ,
    input                                       pos_dir8                    ,


    input                                       neg_dir0                    ,
    input                                       neg_dir1                    ,
    input                                       neg_dir2                    ,
    input                                       neg_dir3                    ,
    input                                       neg_dir4                    ,
    input                                       neg_dir5                    ,
    input                                       neg_dir6                    ,
    input                                       neg_dir7                    ,
    input                                       neg_dir8                    ,

    input                                       bi_dir0                     ,
    input                                       bi_dir1                     ,
    input                                       bi_dir2                     ,
    input                                       bi_dir3                     ,
    input                                       bi_dir4                     ,
    input                                       bi_dir5                     ,
    input                                       bi_dir6                     ,
    input                                       bi_dir7                     ,
    input                                       bi_dir8                     ,


    output wire                                 pos_pulse0                  ,
    output wire                                 pos_pulse1                  ,
    output wire                                 pos_pulse2                  ,
    output wire                                 pos_pulse3                  ,
    output wire                                 pos_pulse4                  ,
    output wire                                 pos_pulse5                  ,
    output wire                                 pos_pulse6                  ,
    output wire                                 pos_pulse7                  ,
    output wire                                 pos_pulse8                  ,

    output wire                                 neg_pulse0                  ,
    output wire                                 neg_pulse1                  ,
    output wire                                 neg_pulse2                  ,
    output wire                                 neg_pulse3                  ,
    output wire                                 neg_pulse4                  ,
    output wire                                 neg_pulse5                  ,
    output wire                                 neg_pulse6                  ,
    output wire                                 neg_pulse7                  ,
    output wire                                 neg_pulse8                  ,

    output wire                                 bi_pulse0                   ,
    output wire                                 bi_pulse1                   ,
    output wire                                 bi_pulse2                   ,
    output wire                                 bi_pulse3                   ,
    output wire                                 bi_pulse4                   ,
    output wire                                 bi_pulse5                   ,
    output wire                                 bi_pulse6                   ,
    output wire                                 bi_pulse7                   ,
    output wire                                 bi_pulse8                   

);
  

U0_SinglePulse u_U0_SinglePulse_Core0(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .bi_dir                                    (bi_dir0                    ),
    .pos_dir                                   (pos_dir0                   ),
    .neg_dir                                   (neg_dir0                   ),
    .bi_pulse                                  (bi_pulse0                  ),
    .pos_pulse                                 (pos_pulse0                 ),
    .neg_pulse                                 (neg_pulse0                 ) 
);


U0_SinglePulse u_U0_SinglePulse_Core1(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .bi_dir                                    (bi_dir1                    ),
    .pos_dir                                   (pos_dir1                   ),
    .neg_dir                                   (neg_dir1                   ),
    .bi_pulse                                  (bi_pulse1                  ),
    .pos_pulse                                 (pos_pulse1                 ),
    .neg_pulse                                 (neg_pulse1                 ) 
);

U0_SinglePulse u_U0_SinglePulse_Core2(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .bi_dir                                    (bi_dir2                    ),
    .pos_dir                                   (pos_dir2                   ),
    .neg_dir                                   (neg_dir2                   ),
    .bi_pulse                                  (bi_pulse2                  ),
    .pos_pulse                                 (pos_pulse2                 ),
    .neg_pulse                                 (neg_pulse2                 ) 
);

U0_SinglePulse u_U0_SinglePulse_Core3(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .bi_dir                                    (bi_dir3                    ),
    .pos_dir                                   (pos_dir3                   ),
    .neg_dir                                   (neg_dir3                   ),
    .bi_pulse                                  (bi_pulse3                  ),
    .pos_pulse                                 (pos_pulse3                 ),
    .neg_pulse                                 (neg_pulse3                 ) 
);

U0_SinglePulse u_U0_SinglePulse_Core4(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .bi_dir                                    (bi_dir4                    ),
    .pos_dir                                   (pos_dir4                   ),
    .neg_dir                                   (neg_dir4                   ),
    .bi_pulse                                  (bi_pulse4                  ),
    .pos_pulse                                 (pos_pulse4                 ),
    .neg_pulse                                 (neg_pulse4                 ) 
);

U0_SinglePulse u_U0_SinglePulse_Core5(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .bi_dir                                    (bi_dir5                    ),
    .pos_dir                                   (pos_dir5                   ),
    .neg_dir                                   (neg_dir5                   ),
    .bi_pulse                                  (bi_pulse5                  ),
    .pos_pulse                                 (pos_pulse5                 ),
    .neg_pulse                                 (neg_pulse5                 ) 
);

U0_SinglePulse u_U0_SinglePulse_Core6(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .bi_dir                                    (bi_dir6                    ),
    .pos_dir                                   (pos_dir6                   ),
    .neg_dir                                   (neg_dir6                   ),
    .bi_pulse                                  (bi_pulse6                  ),
    .pos_pulse                                 (pos_pulse6                 ),
    .neg_pulse                                 (neg_pulse6                 ) 
);

U0_SinglePulse u_U0_SinglePulse_Core7(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .bi_dir                                    (bi_dir7                    ),
    .pos_dir                                   (pos_dir7                   ),
    .neg_dir                                   (neg_dir7                   ),
    .bi_pulse                                  (bi_pulse7                  ),
    .pos_pulse                                 (pos_pulse7                 ),
    .neg_pulse                                 (neg_pulse7                 ) 
);

U0_SinglePulse u_U0_SinglePulse_Core8(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .bi_dir                                    (bi_dir8                    ),
    .pos_dir                                   (pos_dir8                   ),
    .neg_dir                                   (neg_dir8                   ),
    .bi_pulse                                  (bi_pulse8                  ),
    .pos_pulse                                 (pos_pulse8                 ),
    .neg_pulse                                 (neg_pulse8                 ) 
);


endmodule                                                          
                                                     
