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
// Last modified Date:     2025/03/17 18:04:02 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/17 18:04:02 
// Version:                V1.0 
// TEXT NAME:              U2_MBDS_8CH.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U2_MBDS_8CH.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U2_MBDS_8CH #(
    parameter                 CHANNEL_NUM                 = 8     ,
    parameter                 DATA_WIDTH                  = 8     ,
    parameter                 H_DISP                      = 640   ,
    parameter                 V_DISP                      = 480   
)(
    input                                       clk                         ,
    input                                       rst                         ,
    
    input                                       ena                         ,//!系统启动信号

    input                                       data_valid                  ,//!数据有效信号
    input                     [   7: 0]         data_in  [7: 0]             ,//!数据输入

    output wire               [  11: 0]         MB_dout  [1:0]              ,//!宏块数据输出
    output wire                                 MB_ena                      ,//!宏块数据有效

    output wire               [  11: 0]         Sub_dout                    ,//!下采样数据输�???
    output wire                                 Sub_ena                     ,//!下采样数据有�???

    output wire                                 finish_flag                 ,//!�??张图处理完成
    input                                       flag_clr                     //!清除系统状�?

);

    reg                       [   1: 0]         cnt                         ;
    reg                       [$clog2(H_DISP/8) -1: 0] line_cnt             ;
    wire                      [DATA_WIDTH +1      : 0] data_out0            ;
    wire                      [DATA_WIDTH +1      : 0] data_out1            ;
    wire                                        o_dval                      ;
    wire                      [  20: 0]         to_pixel4                   ;
    wire                      [  20: 0]         to_fifo_mux                 ;
    wire                      [  24: 0]         to_fifo                     ;
    wire                      [  23: 0]         fifo_to_pixel4              ;
    wire                                        fifo_empty                  ;
    wire                      [  12: 0]         p4_to_demux0                ;
    wire                      [  12: 0]         p4_to_demux1                ;
    wire                                        p4_to_demux_val             ;
    wire                      [  24: 0]         out_demux_to_fifo           ;
    wire                      [  24: 0]         out_demux_to_out            ;


    reg                       [   0: 0]         sub_cnt                     ;
    reg                       [$clog2(H_DISP/16)-1: 0] sub_line_cnt         ;
    reg                       [  12: 0]         sub_data_out                ;
    reg                                         sub_o_dval                  ;
    wire                      [  13: 0]         to_pixel2                   ;
    wire                      [  13: 0]         p2_to_fifo_mux              ;
    wire                      [  12: 0]         fifo_to_pixel2              ;
    reg                       [  13: 0]         p2_to_demux                 ;
    reg                                         p2_to_demux_val             ;
    reg                                         start                       ;

U2_0_8p_add#(
    .DATA_WIDTH                                (8                          ) 
)
u_U2_0_8p_add(
    .clk                                       (clk                        ),
    .rst                                       (rst | flag_clr             ),
    .i_dval                                    (data_valid & start         ),
    .data_in0                                  (data_in[0]                 ),
    .data_in1                                  (data_in[1]                 ),
    .data_in2                                  (data_in[2]                 ),
    .data_in3                                  (data_in[3]                 ),
    .data_in4                                  (data_in[4]                 ),
    .data_in5                                  (data_in[5]                 ),
    .data_in6                                  (data_in[6]                 ),
    .data_in7                                  (data_in[7]                 ),
    .data_out0                                 (data_out0                  ),
    .data_out1                                 (data_out1                  ),
    .o_dval                                    (o_dval                     ) 
);


    always @(posedge clk ) 
    begin
        if (rst) begin
            start                   <=          1'b0                        ;
        end else begin
            if (ena) begin
                start               <=          1'b1                        ;
            end 
            else if (finish_flag) begin
                start               <=          1'b0                        ;
            end
            else begin
                start               <=          start                       ;
            end
        end
    end

    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            line_cnt                <=          'b0                         ;
        end
        else begin
            if (o_dval) begin
                if (line_cnt == H_DISP/8 - 1) begin
                    line_cnt        <=          'b0                         ;
                end 
                else begin
                    line_cnt        <=          line_cnt + 1                ;
                end
            end 
            else begin
                line_cnt            <=          line_cnt                    ;
            end
        end
    end

    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            cnt                     <=          'b0                         ;
        end else begin
            if (o_dval) begin
                if (line_cnt == H_DISP/8 - 1) begin
                    cnt             <=          cnt + 1                     ;
                end else begin
                    cnt             <=          cnt                         ;
                end
            end else begin
                cnt                 <=          cnt                         ;
            end
        end
    end



u_1_to_2_DEMUX#(
    .D_WIDTH                                   (21                         ) 
)
pixel8_out(
    .o_port0                                   (to_pixel4                  ),
    .o_port1                                   (to_fifo_mux                ),
    .sel                                       (cnt == 2'b00               ),
    .i_port                                    ({o_dval,data_out1,data_out0}) 
);



u_2_to_1_MUX#(
    .D_WIDTH                                   (25                         ) 
)
u_FIFO_IN(
    .i_port0                                   (out_demux_to_fifo          ),
    .i_port1                                   ({to_fifo_mux[20],2'b00,to_fifo_mux[19:10],2'b00,to_fifo_mux[9:0]}),
    .sel                                       (cnt == 2'b00               ),
    .o_port_sel                                (to_fifo                    ) 
);



u_Sync_FIFO_FWFT#(
    .DATA_WIDTH                                (24                         ),
    .DATA_DEPTH                                (H_DISP / 8                 ) //H_DISP / 4
)
u_u_Sync_FIFO_FWFT(
    .clk                                       (clk                        ),// ϵͳʱ��
    .rst                                       (rst | flag_clr             ),// �͵�ƽ��Ч�ĸ�λ�ź�
    .data_in                                   (to_fifo[23:0]              ),// д�������???
    .rd_en                                     (to_pixel4[20]              ),// ��ʹ���źţ��ߵ�ƽ��Ч
    .wr_en                                     (to_fifo[24]                ),// дʹ���źţ��ߵ�ƽ��Ч
    .data_out                                  (fifo_to_pixel4             ) // ���������???
);


U2_1_4p_add#(
    .DATA_WIDTH                                (12                         ) 
)
u_U2_1_4p_add(
    .clk                                       (clk                        ),
    .rst                                       (rst | flag_clr             ),
    .i_dval                                    (to_pixel4[20]              ),//DEMUX i_dval
    .data_in0                                  ({2'b00,to_pixel4[9:0]}     ),//DEMUX output
    .data_in1                                  ({2'b00,to_pixel4[19:10]}   ),//DEMUX output
    .data_in2                                  (fifo_to_pixel4[11:0]       ),//FIFO output
    .data_in3                                  (fifo_to_pixel4[23:12]      ),//FIFO output
    .data_out0                                 (p4_to_demux0               ),
    .data_out1                                 (p4_to_demux1               ),
    .o_dval                                    (p4_to_demux_val            ) 
);


u_1_to_2_DEMUX#(
    .D_WIDTH                                   (25                         ) 
)
u_u_1_to_2_DEMUX(
    .o_port0                                   (out_demux_to_fifo          ),
    .o_port1                                   (out_demux_to_out           ),
    .sel                                       (cnt == 2'b11               ),
    .i_port                                    ({p4_to_demux_val,p4_to_demux1,p4_to_demux0}) 
);

    assign                       MB_ena      =  out_demux_to_out[24];
    assign                       MB_dout[0]  =  out_demux_to_out[11:0];
    assign                       MB_dout[1]  =  out_demux_to_out[23:11];

//---------------------------------------------------------------------------------------
// Sub_Calculate                                                                                    
//---------------------------------------------------------------------------------------

    reg                       [$clog2(V_DISP)-1: 0]         v_cnt           ;
    reg                                         finish_sys                  ;

    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            sub_data_out                <=          'b0                     ;
        end
        else begin
            if (MB_ena) begin
                sub_data_out            <=          MB_dout[0] + MB_dout[1] ;
            end
            else begin
                sub_data_out            <=          'b0                     ;
            end     
        end
    end

    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            sub_o_dval                  <=          'b0                     ;
        end else begin
            sub_o_dval                  <=          MB_ena                  ;
        end
    end


    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            sub_line_cnt                <=          'b0                     ;
        end
        else begin
            if (sub_o_dval) begin
                if (sub_line_cnt == H_DISP/16 - 1) begin
                    sub_line_cnt        <=          'b0                     ;
                end 
                else begin
                    sub_line_cnt        <=          sub_line_cnt + 1        ;
                end
            end 
            else begin
                sub_line_cnt            <=          sub_line_cnt            ;
            end
        end
    end

    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            v_cnt                       <=          'b0                     ;
            finish_sys                  <=          1'b0                    ;
        end else begin
            if (sub_o_dval) begin
                if (sub_line_cnt == H_DISP/16 - 1) begin
                    if (v_cnt == V_DISP/4 - 1) begin
                        v_cnt           <=          'b0                     ;
                        finish_sys      <=          1'b1                    ;
                    end else begin
                        v_cnt           <=          v_cnt + 1               ;
                        finish_sys      <=          1'b0                    ;
                    end
                end else begin
                    v_cnt               <=          v_cnt                   ;
                    finish_sys          <=          1'b0                    ;
                end
            end else begin
                v_cnt                   <=          v_cnt                   ;
                finish_sys              <=          1'b0                    ;
            end
        end
    end

    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            sub_cnt                     <=          'b0                     ;
        end else begin
            if (sub_o_dval) begin
                if (sub_line_cnt == H_DISP/16 - 1) begin
                    sub_cnt             <=          sub_cnt + 1             ;
                end else begin
                    sub_cnt             <=          sub_cnt                 ;
                end
            end else begin
                sub_cnt                 <=          sub_cnt                 ;
            end
        end
    end
    

    u_1_to_2_DEMUX#(
    .D_WIDTH                                   (14                         ) 
    )
    add2_out(
    .o_port0                                   (to_pixel2                  ),
    .o_port1                                   (p2_to_fifo_mux             ),
    .sel                                       (sub_cnt == 1'b0            ),
    .i_port                                    ({sub_o_dval,sub_data_out}  ) 
    );
        

    u_Sync_FIFO_FWFT#(
    .DATA_WIDTH                                (13                         ),
    .DATA_DEPTH                                (H_DISP / 16                ) //H_DISP / 4
    )
    u_sub_Sync_FIFO_FWFT(
    .clk                                       (clk                        ),// ϵͳʱ��
    .rst                                       (rst | flag_clr             ),// �͵�ƽ��Ч�ĸ�λ�ź�
    .data_in                                   (p2_to_fifo_mux[12:0]       ),// д�������???
    .rd_en                                     (to_pixel2[13]              ),// ��ʹ���źţ��ߵ�ƽ��Ч
    .wr_en                                     (p2_to_fifo_mux[13]         ),// дʹ���źţ��ߵ�ƽ��Ч
    .data_out                                  (fifo_to_pixel2             ) // ���������???
    );
    
    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            p2_to_demux                 <=      'b0                         ;
        end else begin
            if (to_pixel2[13]) begin
                p2_to_demux             <=      fifo_to_pixel2 + to_pixel2[12:0];
            end else begin
                p2_to_demux             <=      'b0                         ;
            end
        end
    end

    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            p2_to_demux_val             <=      'b0                         ;
        end else begin
            p2_to_demux_val             <=      to_pixel2[13]               ;
        end
    end
    
    assign                       Sub_ena      =  p2_to_demux_val            ;
    assign                       Sub_dout     =  p2_to_demux  >> 2          ;


U0_SinglePulse u_U0_SinglePulse(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .pos_dir                                   (finish_sys                 ),
    .pos_pulse                                 (finish_flag                ) 
);



endmodule                                                          
