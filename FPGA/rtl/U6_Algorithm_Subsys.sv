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
// Last modified Date:     2025/02/17 23:09:44 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/02/17 23:09:44 
// Version:                V1.0 
// TEXT NAME:              U6_Algorithm_Subsys.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3D_NoiseReduce\3D_NoiseReduce.srcs\sources_1\imports\3D_Denoise\U6_Algorithm_Subsys.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U6_Algorithm_Subsys #(
    parameter                 DDR_BASE_ADDR               = 0     ,
    parameter                 WAIT                        = 10    ,
    parameter                 HSYNC_PERIOD                = 128   ,
    parameter                 VSYNC_PERIOD                = 2     ,
    parameter                 H_BACK_PORCH                = 88    ,
    parameter                 H_DISP                      = 640   ,
    parameter                 H_FRONT_PORCH               = 40    ,
    parameter                 V_BACK_PORCH                = 33    ,
    parameter                 V_DISP                      = 480   ,
    parameter                 V_FRONT_PORCH               = 10    ,
    parameter                 CHANNEL_NUM                 = 8     

)(

    input                                       clk                         ,
    input                                       rst                         ,
    input                     [   7: 0]         i_temporal_weight           ,
    
    //-----------------------------------------------------------------------
    //
    //-----------------------------------------------------------------------

    input                                       i_start_sys                 ,
    input                     [  13: 0]         i_macroblock_addr           ,
    input                                       i_select_tmp_R              ,
    input                                       i_select_tmp_G              ,
    input                                       i_select_tmp_B              ,

    //-----------------------------------------------------------------------
    //
    //-----------------------------------------------------------------------
    output wire                                 o_rd_ena         [2:0][CHANNEL_NUM -1: 0],
    output wire               [  11: 0]         o_rd_address     [2:0][CHANNEL_NUM -1: 0],
    input                     [   7: 0]         i_rd_data_process[2:0][CHANNEL_NUM -1: 0],
    input                     [   7: 0]         i_rd_data_match  [2:0][CHANNEL_NUM -1: 0],

    //-----------------------------------------------------------------------
    //
    //-----------------------------------------------------------------------

    input                                       i_one_finish_clr            ,
    output wire                                 o_one_MB_finish             ,//一个宏块完毕
    output wire                                 o_image_out_start           ,
    output wire                                 o_line_transfer_finish_pulse,//列完成和帧完成如果有效，则同时拉高
    output wire                                 o_frame_finish_pulse        ,//ָ列完成和帧完成如果有效，则同时拉高

    //-----------------------------------------------------------------------
    //
    //-----------------------------------------------------------------------

    output wire               [   7: 0]         o_posted_data_R[CHANNEL_NUM -1: 0],
    output wire               [   7: 0]         o_posted_data_G[CHANNEL_NUM -1: 0],
    output wire               [   7: 0]         o_posted_data_B[CHANNEL_NUM -1: 0],

    output wire                                 o_d_val                     ,
    output wire                                 o_Vsync                     ,
    output wire                                 o_Hsync                     
);

    wire                                        o_one_block_process_finish  ;

    wire                                        o_one_block_process_finish_R;
    wire                                        o_one_block_process_finish_G;
    wire                                        o_one_block_process_finish_B;

    reg                                         block_finish_R              ;
    reg                                         block_finish_G              ;
    reg                                         block_finish_B              ;

    //----------------------------------------------------------------------
    // 行处理                                                                
    //----------------------------------------------------------------------

    reg                                         i_image_out_start           ;

    reg                                         o_line_ready_2_out_R        ;
    reg                                         o_line_ready_2_out_G        ;
    reg                                         o_line_ready_2_out_B        ;

    wire                                        o_line_transfer_finish_pulse_R ;
    wire                                        o_line_transfer_finish_pulse_G ;
    wire                                        o_line_transfer_finish_pulse_B ;

    wire                                        o_line_finish_pulse_R       ;
    wire                                        o_line_finish_pulse_G       ;
    wire                                        o_line_finish_pulse_B       ;

    wire                                        o_frame_finish_pulse_R      ;
    wire                                        o_frame_finish_pulse_G      ;
    wire                                        o_frame_finish_pulse_B      ;

    wire                      [   7: 0]         o_posted_data_R [CHANNEL_NUM -1: 0];
    wire                                        o_d_val_R                   ;
    wire                                        o_Vsync_R                   ;
    wire                                        o_Hsync_R                   ;

    wire                      [   7: 0]         o_posted_data_G [CHANNEL_NUM -1: 0];
    wire                                        o_d_val_G                   ;
    wire                                        o_Vsync_G                   ;
    wire                                        o_Hsync_G                   ;

    wire                      [   7: 0]         o_posted_data_B [CHANNEL_NUM -1: 0];
    wire                                        o_d_val_B                   ;
    wire                                        o_Vsync_B                   ;
    wire                                        o_Hsync_B                   ;

    assign o_d_val = o_d_val_R & o_d_val_G & o_d_val_B;

    assign o_Vsync       = o_Vsync_R & o_Vsync_G & o_Vsync_B;
    assign o_Hsync       = o_Hsync_R & o_Hsync_G & o_Hsync_B;

    assign o_one_block_process_finish   =       block_finish_R & block_finish_G & block_finish_B;

    assign o_image_out_start            =       i_image_out_start_pulse     ;

    assign o_line_transfer_finish_pulse =       o_line_transfer_finish_pulse_R ;//哪个都行，因为传输速度都是一致的

    assign o_frame_finish_pulse         =       o_frame_finish_pulse_R & o_frame_finish_pulse_G & o_frame_finish_pulse_B;

U0_SinglePulse_SubSys u_U0_image_out_start(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .pos_dir0                                  (i_image_out_start          ),
    .pos_pulse0                                (i_image_out_start_pulse    )
);

U0_SinglePulse_SubSys u_U0_block_finish(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .pos_dir0                                  (o_one_block_process_finish ),
    .pos_pulse0                                (o_one_MB_finish            ) 
);


always @(posedge clk ) begin
    if (rst) begin
        block_finish_R          <=          1'b0                            ;
        block_finish_G          <=          1'b0                            ;
        block_finish_B          <=          1'b0                            ;
    end 
    else begin
        if (i_one_finish_clr) begin
            block_finish_R      <=          1'b0                            ;
        end
        else if (o_one_block_process_finish_R) begin
            block_finish_R      <=          1'b1                            ;
        end 
        else begin
            block_finish_R      <=          block_finish_R                  ;
        end

        if (i_one_finish_clr) begin
            block_finish_G      <=          1'b0                            ;
        end
        else if (o_one_block_process_finish_G) begin
            block_finish_G      <=          1'b1                            ;
        end 
        else begin
            block_finish_G      <=          block_finish_G                  ;
        end

        if (i_one_finish_clr) begin
            block_finish_B      <=          1'b0                            ;
        end
        else if (o_one_block_process_finish_B) begin
            block_finish_B      <=          1'b1                            ;
        end 
        else begin
            block_finish_B      <=          block_finish_B                  ;
        end
    end
end


always @(posedge clk ) begin
    if (rst) begin
        i_image_out_start       <=          1'b0                            ;
    end
    else begin
        if (o_line_ready_2_out_R & o_line_ready_2_out_G & o_line_ready_2_out_B) begin
            i_image_out_start   <=          1'b1                            ;
        end
        else begin
            i_image_out_start   <=          1'b0                            ;
        end    
    end
end


always @(posedge clk ) begin
    if (rst) begin
        o_line_ready_2_out_R    <=          1'b0                            ;
        o_line_ready_2_out_G    <=          1'b0                            ;
        o_line_ready_2_out_B    <=          1'b0                            ;
    end
    else begin
        if (i_image_out_start_pulse) begin
            o_line_ready_2_out_R<=          1'b0                            ;
        end
        else if (o_line_finish_pulse_R) begin
            o_line_ready_2_out_R<=          1'b1                            ;
        end
        else begin
            o_line_ready_2_out_R<=          o_line_ready_2_out_R            ;
        end

        if (i_image_out_start_pulse) begin
            o_line_ready_2_out_G<=          1'b0                            ;
        end
        else if (o_line_finish_pulse_G) begin
            o_line_ready_2_out_G<=          1'b1                            ;
        end
        else begin
            o_line_ready_2_out_G<=          o_line_ready_2_out_G            ;
        end

        if (i_image_out_start_pulse) begin
            o_line_ready_2_out_B<=          1'b0                            ;
        end
        else if (o_line_finish_pulse_B) begin
            o_line_ready_2_out_B<=          1'b1                            ;
        end
        else begin
            o_line_ready_2_out_B<=          o_line_ready_2_out_B            ;
        end

    end
end

U6_Algorithm_sys#(
    .DDR_BASE_ADDR                             (DDR_BASE_ADDR              ),
    .WAIT                                      (WAIT                       ),
    .HSYNC_PERIOD                              (HSYNC_PERIOD               ),
    .VSYNC_PERIOD                              (VSYNC_PERIOD               ),
    .H_BACK_PORCH                              (H_BACK_PORCH               ),
    .H_DISP                                    (H_DISP                     ),
    .H_FRONT_PORCH                             (H_FRONT_PORCH              ),
    .V_BACK_PORCH                              (V_BACK_PORCH               ),
    .V_DISP                                    (V_DISP                     ),
    .V_FRONT_PORCH                             (V_FRONT_PORCH              ),
    .CHANNEL_NUM                               (8                          ) 
)
u_U6_Algorithm_sys_R(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .i_temporal_weight                         (i_temporal_weight          ),

    .i_start_sys                               (i_start_sys                ),
    .i_select_tmp                              (i_select_tmp_R             ),
    .i_macroblock_addr                         (i_macroblock_addr          ),

    .o_rd_ena                                  (o_rd_ena[0]                ),
    .o_rd_address                              (o_rd_address[0]            ),
    .i_rd_data_process                         (i_rd_data_process[0]       ),
    .i_rd_data_match                           (i_rd_data_match[0]         ),
    
    .o_one_block_process_finish                (o_one_block_process_finish_R),// ָʾ������洢���
    .i_one_finish_clr                          (i_one_finish_clr           ),
    
    .i_image_out_start                         (i_image_out_start_pulse    ),
    .o_line_finish_pulse                       (o_line_finish_pulse_R      ),// ָʾ�ⲿ������һ���Ļ�·��BRAM�߼�������·�����ټ�⣬ͬʱԤȡDDR�ٹ���
    .o_line_transfer_finish_pulse              (o_line_transfer_finish_pulse_R),// ��ʾĿǰ4�д������
    .o_frame_finish_pulse                      (o_frame_finish_pulse_R     ),// ָʾһ��֡������������

    .o_posted_data                             (o_posted_data_R            ),
    .o_d_val                                   (o_d_val_R                  ),
    .o_Vsync                                   (o_Vsync_R                  ),
    .o_Hsync                                   (o_Hsync_R                  ) 
);


U6_Algorithm_sys#(
    .DDR_BASE_ADDR                             (DDR_BASE_ADDR              ),
    .WAIT                                      (WAIT                       ),
    .HSYNC_PERIOD                              (HSYNC_PERIOD               ),
    .VSYNC_PERIOD                              (VSYNC_PERIOD               ),
    .H_BACK_PORCH                              (H_BACK_PORCH               ),
    .H_DISP                                    (H_DISP                     ),
    .H_FRONT_PORCH                             (H_FRONT_PORCH              ),
    .V_BACK_PORCH                              (V_BACK_PORCH               ),
    .V_DISP                                    (V_DISP                     ),
    .V_FRONT_PORCH                             (V_FRONT_PORCH              ),
    .CHANNEL_NUM                               (8                          ) 
)
u_U6_Algorithm_sys_G(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .i_temporal_weight                         (i_temporal_weight          ),

    .i_start_sys                               (i_start_sys                ),
    .i_select_tmp                              (i_select_tmp_G             ),
    .i_macroblock_addr                         (i_macroblock_addr          ),

    .o_rd_ena                                  (o_rd_ena[1]                 ),
    .o_rd_address                              (o_rd_address[1]             ),
    .i_rd_data_process                         (i_rd_data_process[1]        ),
    .i_rd_data_match                           (i_rd_data_match[1]          ),
    
    .o_one_block_process_finish                (o_one_block_process_finish_G),// ָʾ������洢���
    .i_one_finish_clr                          (i_one_finish_clr           ),
    
    .i_image_out_start                         (i_image_out_start_pulse    ),
    .o_line_finish_pulse                       (o_line_finish_pulse_G      ),// ָʾ�ⲿ������һ���Ļ�·��BRAM�߼�������·�����ټ�⣬ͬʱԤȡDDR�ٹ���
    .o_line_transfer_finish_pulse              (o_line_transfer_finish_pulse_G),// ��ʾĿǰ4�д������
    .o_frame_finish_pulse                      (o_frame_finish_pulse_G     ),// ָʾһ��֡������������

    .o_posted_data                             (o_posted_data_G            ),
    .o_d_val                                   (o_d_val_G                  ),
    .o_Vsync                                   (o_Vsync_G                  ),
    .o_Hsync                                   (o_Hsync_G                  ) 
);



U6_Algorithm_sys#(
    .DDR_BASE_ADDR                             (DDR_BASE_ADDR              ),
    .WAIT                                      (WAIT                       ),
    .HSYNC_PERIOD                              (HSYNC_PERIOD               ),
    .VSYNC_PERIOD                              (VSYNC_PERIOD               ),
    .H_BACK_PORCH                              (H_BACK_PORCH               ),
    .H_DISP                                    (H_DISP                     ),
    .H_FRONT_PORCH                             (H_FRONT_PORCH              ),
    .V_BACK_PORCH                              (V_BACK_PORCH               ),
    .V_DISP                                    (V_DISP                     ),
    .V_FRONT_PORCH                             (V_FRONT_PORCH              ),
    .CHANNEL_NUM                               (8                          ) 
)
u_U6_Algorithm_sys_B(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .i_temporal_weight                         (i_temporal_weight          ),

    .i_start_sys                               (i_start_sys                ),
    .i_select_tmp                              (i_select_tmp_B             ),
    .i_macroblock_addr                         (i_macroblock_addr          ),

    .o_rd_ena                                  (o_rd_ena[2]                 ),
    .o_rd_address                              (o_rd_address[2]             ),
    .i_rd_data_process                         (i_rd_data_process[2]        ),
    .i_rd_data_match                           (i_rd_data_match[2]          ),
    
    .o_one_block_process_finish                (o_one_block_process_finish_B),// ָʾ������洢���
    .i_one_finish_clr                          (i_one_finish_clr           ),
    
    .i_image_out_start                         (i_image_out_start_pulse    ),
    .o_line_finish_pulse                       (o_line_finish_pulse_B      ),// ָʾ�ⲿ������һ���Ļ�·��BRAM�߼�������·�����ټ�⣬ͬʱԤȡDDR�ٹ���
    .o_line_transfer_finish_pulse              (o_line_transfer_finish_pulse_B),// ��ʾĿǰ4�д������
    .o_frame_finish_pulse                      (o_frame_finish_pulse_B     ),// ָʾһ��֡������������

    .o_posted_data                             (o_posted_data_B            ),
    .o_d_val                                   (o_d_val_B                  ),
    .o_Vsync                                   (o_Vsync_B                  ),
    .o_Hsync                                   (o_Hsync_B                  ) 
);


endmodule                                                          
