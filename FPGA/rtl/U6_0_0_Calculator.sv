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
// Last modified Date:     2025/02/10 02:27:18 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/02/10 02:27:18 
// Version:                V1.0 
// TEXT NAME:              U7_1_0_2_0_Calculator.v 
// PATH:                   D:\EDA_Work_Space\CCIC_ISP_OV5640\CCIC_ISP_OV5640.srcs\sources_1\new\U7_1_0_2_0_Calculator.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U6_0_0_Calculator(
    input                               clk                        ,
    input                               rst                        ,
    input                               d_valid                    ,
    input              [   7: 0]        din_0                      ,
    input              [   7: 0]        din_1                      ,
    input              [   7: 0]        din_2                      ,
    input              [   7: 0]        din_3                      ,
    input              [   7: 0]        din_4                      ,
    input              [   7: 0]        din_5                      ,
    input              [   7: 0]        din_6                      ,
    input              [   7: 0]        din_7                      ,
    input              [   7: 0]        din_8                      ,
    output wire        [   7: 0]        d_out                      ,
    output wire                         d_out_valid                 
    
    );
                                                 

    reg                [   7: 0]        ena_d                       ;
    reg                [   7: 0]        din_d1     [8:0]            ;//�����ӳ�
    reg                [   7: 0]        din_d2     [8:0]            ;
    reg                [   7: 0]        din_d3     [8:0]            ;
    reg                [   7: 0]        din_d4     [8:0]            ;


    //sigma = 25 ��ϸֵ��Ҫ�Լ�����֮�󶨵㻯
    wire               [   7: 0]        c_weight_0                  ;
    wire               [   7: 0]        c_weight_1                  ;
    wire               [   7: 0]        c_weight_2                  ;
    wire               [   7: 0]        c_weight_3                  ;
    wire               [   7: 0]        c_weight_4                  ;
    wire               [   7: 0]        c_weight_5                  ;
    wire               [   7: 0]        c_weight_6                  ;
    wire               [   7: 0]        c_weight_7                  ;
    wire               [   7: 0]        c_weight_8                  ;
    reg                [  15: 0]        c_mul_s    [8:0]            ;

    reg                [   7: 0]        s_weight   [2:0]            ;//0:���� 1:ŷʽ���� 1 2:ŷʽ���� ��2
    reg                [   7: 0]        lut_in_0                    ;
    reg                [   7: 0]        lut_in_1                    ;
    reg                [   7: 0]        lut_in_2                    ;
    reg                [   7: 0]        lut_in_3                    ;
    reg                [   7: 0]        lut_in_4                    ;
    reg                [   7: 0]        lut_in_5                    ;
    reg                [   7: 0]        lut_in_6                    ;
    reg                [   7: 0]        lut_in_7                    ;
    reg                [   7: 0]        lut_in_8                    ;
    reg                [  23: 0]        MUL2       [8:0]            ;
    reg                [  16: 0]        sum1_1     [3:0]            ;
    reg                [  17: 0]        sum1_2     [1:0]            ;
    reg                [  18: 0]        SUM1                        ;
    reg                [  18: 0]        SUM1_d                      ;
    reg                [  24: 0]        sum2_1     [3:0]            ;
    reg                [  25: 0]        sum2_2     [1:0]            ;
    reg                [  26: 0]        SUM2                        ;

    always @(posedge clk ) begin
        if (rst) begin
            s_weight[0]         <=         8'd128                    ;
            s_weight[1]         <=         8'd77                     ;
            s_weight[2]         <=         8'd47                     ;
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            ena_d               <=         'b0                       ;
        end 
        else begin
            ena_d[0]            <=         d_valid                   ;
            ena_d[1]            <=         ena_d[0]                  ;
            ena_d[2]            <=         ena_d[1]                  ;
            ena_d[3]            <=         ena_d[2]                  ;
            ena_d[4]            <=         ena_d[3]                  ;
            ena_d[5]            <=         ena_d[4]                  ;
            ena_d[6]            <=         ena_d[5]                  ;
            ena_d[7]            <=         ena_d[6]                  ;
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            din_d1[0]           <=         'b0                       ; 
            din_d1[1]           <=         'b0                       ; 
            din_d1[2]           <=         'b0                       ; 
            din_d1[3]           <=         'b0                       ; 
            din_d1[4]           <=         'b0                       ; 
            din_d1[5]           <=         'b0                       ; 
            din_d1[6]           <=         'b0                       ; 
            din_d1[7]           <=         'b0                       ; 
            din_d1[8]           <=         'b0                       ; 

            din_d2[0]           <=         'b0                       ; 
            din_d2[1]           <=         'b0                       ; 
            din_d2[2]           <=         'b0                       ; 
            din_d2[3]           <=         'b0                       ; 
            din_d2[4]           <=         'b0                       ; 
            din_d2[5]           <=         'b0                       ; 
            din_d2[6]           <=         'b0                       ; 
            din_d2[7]           <=         'b0                       ; 
            din_d2[8]           <=         'b0                       ; 

            din_d3[0]           <=         'b0                       ; 
            din_d3[1]           <=         'b0                       ; 
            din_d3[2]           <=         'b0                       ; 
            din_d3[3]           <=         'b0                       ; 
            din_d3[4]           <=         'b0                       ; 
            din_d3[5]           <=         'b0                       ; 
            din_d3[6]           <=         'b0                       ; 
            din_d3[7]           <=         'b0                       ; 
            din_d3[8]           <=         'b0                       ; 

            din_d4[0]           <=         'b0                       ; 
            din_d4[1]           <=         'b0                       ; 
            din_d4[2]           <=         'b0                       ; 
            din_d4[3]           <=         'b0                       ; 
            din_d4[4]           <=         'b0                       ; 
            din_d4[5]           <=         'b0                       ; 
            din_d4[6]           <=         'b0                       ; 
            din_d4[7]           <=         'b0                       ; 
            din_d4[8]           <=         'b0                       ; 
        end 
        else begin
            din_d1[0]           <=         din_0                     ;
            din_d1[1]           <=         din_1                     ;
            din_d1[2]           <=         din_2                     ;
            din_d1[3]           <=         din_3                     ;
            din_d1[4]           <=         din_4                     ;
            din_d1[5]           <=         din_5                     ;
            din_d1[6]           <=         din_6                     ;
            din_d1[7]           <=         din_7                     ;
            din_d1[8]           <=         din_8                     ;

            din_d2[0]           <=         din_d1[0]                 ;
            din_d2[1]           <=         din_d1[1]                 ;
            din_d2[2]           <=         din_d1[2]                 ;
            din_d2[3]           <=         din_d1[3]                 ;
            din_d2[4]           <=         din_d1[4]                 ;
            din_d2[5]           <=         din_d1[5]                 ;
            din_d2[6]           <=         din_d1[6]                 ;
            din_d2[7]           <=         din_d1[7]                 ;
            din_d2[8]           <=         din_d1[8]                 ;

            din_d3[0]           <=         din_d2[0]                 ;
            din_d3[1]           <=         din_d2[1]                 ;
            din_d3[2]           <=         din_d2[2]                 ;
            din_d3[3]           <=         din_d2[3]                 ;
            din_d3[4]           <=         din_d2[4]                 ;
            din_d3[5]           <=         din_d2[5]                 ;
            din_d3[6]           <=         din_d2[6]                 ;
            din_d3[7]           <=         din_d2[7]                 ;
            din_d3[8]           <=         din_d2[8]                 ;

            din_d4[0]           <=         din_d3[0]                 ;
            din_d4[1]           <=         din_d3[1]                 ;
            din_d4[2]           <=         din_d3[2]                 ;
            din_d4[3]           <=         din_d3[3]                 ;
            din_d4[4]           <=         din_d3[4]                 ;
            din_d4[5]           <=         din_d3[5]                 ;
            din_d4[6]           <=         din_d3[6]                 ;
            din_d4[7]           <=         din_d3[7]                 ;
            din_d4[8]           <=         din_d3[8]                 ;
        end
    end




    always @(posedge clk ) begin
        if (rst) begin
            lut_in_0        <=      'b0                                 ;
            lut_in_1        <=      'b0                                 ;
            lut_in_2        <=      'b0                                 ;
            lut_in_3        <=      'b0                                 ;
            lut_in_4        <=      'b0                                 ;
            lut_in_5        <=      'b0                                 ;
            lut_in_6        <=      'b0                                 ;
            lut_in_7        <=      'b0                                 ;
            lut_in_8        <=      'b0                                 ;
        end 
        else begin
            if (ena_d[0]) begin
                if (din_d1[4] < din_d1[0]) begin
                    lut_in_0<=      din_d1[0] - din_d1[4]               ;
                end 
                else begin
                    lut_in_0<=      din_d1[4] - din_d1[0]               ;
                end

                if (din_d1[4] < din_d1[1]) begin
                    lut_in_1<=      din_d1[1] - din_d1[4]               ;
                end 
                else begin
                    lut_in_1<=      din_d1[4] - din_d1[1]               ;
                end

                if (din_d1[4] < din_d1[2]) begin
                    lut_in_2<=      din_d1[2] - din_d1[4]               ;
                end 
                else begin
                    lut_in_2<=      din_d1[4] - din_d1[2]               ;
                end

                if (din_d1[4] < din_d1[3]) begin
                    lut_in_3<=      din_d1[3] - din_d1[4]               ;
                end 
                else begin
                    lut_in_3<=      din_d1[4] - din_d1[3]               ;
                end

                if (din_d1[4] < din_d1[5]) begin
                    lut_in_5<=      din_d1[5] - din_d1[4]               ;
                end 
                else begin
                    lut_in_5<=      din_d1[4] - din_d1[5]               ;
                end

                if (din_d1[4] < din_d1[6]) begin
                    lut_in_6<=      din_d1[6] - din_d1[4]               ;
                end 
                else begin
                    lut_in_6<=      din_d1[4] - din_d1[6]               ;
                end

                if (din_d1[4] < din_d1[7]) begin
                    lut_in_7<=      din_d1[7] - din_d1[4]               ;
                end 
                else begin
                    lut_in_7<=      din_d1[4] - din_d1[7]               ;
                end

                if (din_d1[4] < din_d1[8]) begin
                    lut_in_8<=      din_d1[8] - din_d1[4]               ;
                end 
                else begin
                    lut_in_8<=      din_d1[4] - din_d1[8]               ;
                end
            end 
        end
    end


    U6_0_0_0_LUT_Parameter u_U6_0_0_0_LUT_Parameter(
    .clk                                (clk                       ),
    .rst_n                              (~rst                      ),
    .ena                                (ena_d[1]                  ),

    .din_1                              (lut_in_0                  ),
    .din_2                              (lut_in_1                  ),
    .din_3                              (lut_in_2                  ),
    .din_4                              (lut_in_3                  ),
    .din_5                              (lut_in_4                  ),
    .din_6                              (lut_in_5                  ),
    .din_7                              (lut_in_6                  ),
    .din_8                              (lut_in_7                  ),
    .din_9                              (lut_in_8                  ),

    .param_1                            (c_weight_0                ),
    .param_2                            (c_weight_1                ),
    .param_3                            (c_weight_2                ),
    .param_4                            (c_weight_3                ),
    .param_5                            (c_weight_4                ),
    .param_6                            (c_weight_5                ),
    .param_7                            (c_weight_6                ),
    .param_8                            (c_weight_7                ),
    .param_9                            (c_weight_8                ) 
    );



    always @(posedge clk ) begin//û�������𶨵㻯
        if (rst) begin
            c_mul_s[0]                  <=          'b0             ;
            c_mul_s[1]                  <=          'b0             ;
            c_mul_s[2]                  <=          'b0             ;
            c_mul_s[3]                  <=          'b0             ;
            c_mul_s[4]                  <=          'b0             ;
            c_mul_s[5]                  <=          'b0             ;
            c_mul_s[6]                  <=          'b0             ;
            c_mul_s[7]                  <=          'b0             ;
            c_mul_s[8]                  <=          'b0             ;
        end
        else begin
            if (ena_d[2]) begin
                c_mul_s[0]              <= ( c_weight_0 * s_weight[2] );//欠14bit,后边除法替他还债了
                c_mul_s[1]              <= ( c_weight_1 * s_weight[1] );
                c_mul_s[2]              <= ( c_weight_2 * s_weight[2] );
                c_mul_s[3]              <= ( c_weight_3 * s_weight[1] );
                c_mul_s[4]              <= ( c_weight_4 * s_weight[0] );
                c_mul_s[5]              <= ( c_weight_5 * s_weight[1] );
                c_mul_s[6]              <= ( c_weight_6 * s_weight[2] );
                c_mul_s[7]              <= ( c_weight_7 * s_weight[1] );
                c_mul_s[8]              <= ( c_weight_8 * s_weight[2] );
            end 
            else begin
                c_mul_s[0]              <=  c_mul_s[0]              ;
                c_mul_s[1]              <=  c_mul_s[1]              ;
                c_mul_s[2]              <=  c_mul_s[2]              ;
                c_mul_s[3]              <=  c_mul_s[3]              ;
                c_mul_s[4]              <=  c_mul_s[4]              ;
                c_mul_s[5]              <=  c_mul_s[5]              ;
                c_mul_s[6]              <=  c_mul_s[6]              ;
                c_mul_s[7]              <=  c_mul_s[7]              ;
                c_mul_s[8]              <=  c_mul_s[8]              ;
            end
        end
    end


    always @(posedge clk ) begin
        if (rst) begin
            MUL2[0]                     <=          'b0             ;
            MUL2[1]                     <=          'b0             ;
            MUL2[2]                     <=          'b0             ;
            MUL2[3]                     <=          'b0             ;
            MUL2[4]                     <=          'b0             ;
            MUL2[5]                     <=          'b0             ;
            MUL2[6]                     <=          'b0             ;
            MUL2[7]                     <=          'b0             ;
            MUL2[8]                     <=          'b0             ;
        end
        else begin
            if (ena_d[3]) begin
                MUL2[0]                 <=  c_mul_s[0] * din_d3[0]  ;
                MUL2[1]                 <=  c_mul_s[1] * din_d3[1]  ;
                MUL2[2]                 <=  c_mul_s[2] * din_d3[2]  ;
                MUL2[3]                 <=  c_mul_s[3] * din_d3[3]  ;
                MUL2[4]                 <=  c_mul_s[4] * din_d3[4]  ;
                MUL2[5]                 <=  c_mul_s[5] * din_d3[5]  ;
                MUL2[6]                 <=  c_mul_s[6] * din_d3[6]  ;
                MUL2[7]                 <=  c_mul_s[7] * din_d3[7]  ;
                MUL2[8]                 <=  c_mul_s[8] * din_d3[8]  ;

            end
            else begin
                MUL2[0]                 <=  MUL2[0]                 ;
                MUL2[1]                 <=  MUL2[1]                 ;
                MUL2[2]                 <=  MUL2[2]                 ;
                MUL2[3]                 <=  MUL2[3]                 ;
                MUL2[4]                 <=  MUL2[4]                 ;
                MUL2[5]                 <=  MUL2[5]                 ;
                MUL2[6]                 <=  MUL2[6]                 ;
                MUL2[7]                 <=  MUL2[7]                 ;
                MUL2[8]                 <=  MUL2[8]                 ;
            end
        end
    end


    always @(posedge clk ) begin
        if (rst) begin
            sum1_1[0]                   <=  'b0                     ;
            sum1_1[1]                   <=  'b0                     ;
            sum1_1[2]                   <=  'b0                     ;
            sum1_1[3]                   <=  'b0                     ;
        end 
        else begin
            if (ena_d[3]) begin
                sum1_1[0]               <=  c_mul_s[0] + c_mul_s[1]               ;
                sum1_1[1]               <=  c_mul_s[2] + c_mul_s[3]               ;    
                sum1_1[2]               <=  c_mul_s[4] + c_mul_s[5]               ;
                sum1_1[3]               <=  c_mul_s[6] + c_mul_s[7] + c_mul_s[8]  ;
            end 
            else begin
                sum1_1[0]               <=  sum1_1[0]               ;
                sum1_1[1]               <=  sum1_1[1]               ;
                sum1_1[2]               <=  sum1_1[2]               ;
                sum1_1[3]               <=  sum1_1[3]               ;
            end
        end
    end


    always @(posedge clk ) begin
        if (rst) begin
            sum1_2[0]                   <=  'b0                     ;
            sum1_2[1]                   <=  'b0                     ;

        end 
        else begin
            if (ena_d[4]) begin
                sum1_2[0]               <=  sum1_1[0] + sum1_1[1]   ;
                sum1_2[1]               <=  sum1_1[2] + sum1_1[3]   ;
            end 
            else begin
                sum1_2[0]               <=  sum1_2[0]               ;
                sum1_2[1]               <=  sum1_2[1]               ;
            end
        end
    end 


    always @(posedge clk ) begin
        if (rst) begin
            SUM1                        <=  'b0                     ;
        end 
        else begin
            if (ena_d[5]) begin
                SUM1                    <=  sum1_2[0] + sum1_2[1]   ;
            end 
            else begin
                SUM1                    <=  SUM1                    ;    
            end
        end
    end


    always @(posedge clk ) begin
        if (rst) begin
            SUM1_d                      <=  'b0                     ;
        end 
        else begin
            if (ena_d[6]) begin
                SUM1_d                  <=  SUM1                    ;
            end
            else begin
                SUM1_d                  <=  SUM1_d                  ;
            end    
        end
    end



    always @(posedge clk ) begin
        if (rst) begin
            sum2_1[0]                   <=      'b0                 ;
            sum2_1[1]                   <=      'b0                 ;
            sum2_1[2]                   <=      'b0                 ;
            sum2_1[3]                   <=      'b0                 ;
        end 
        else begin
            if (ena_d[4]) begin
                sum2_1[0]               <=  MUL2[0] + MUL2[1]       ;
                sum2_1[1]               <=  MUL2[2] + MUL2[3]       ;
                sum2_1[2]               <=  MUL2[4] + MUL2[5] + MUL2[6];
                sum2_1[3]               <=  MUL2[7] + MUL2[8]       ;
            end 
            else begin
                sum2_1[0]               <=  sum2_1[0]               ;
                sum2_1[1]               <=  sum2_1[1]               ;
                sum2_1[2]               <=  sum2_1[2]               ;
                sum2_1[3]               <=  sum2_1[3]               ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            sum2_2[0]                   <=      'b0                 ;
            sum2_2[1]                   <=      'b0                 ;
        end
        else begin
            if (ena_d[5]) begin
                sum2_2[0]               <=  sum2_1[0] + sum2_1[1]   ;
                sum2_2[1]               <=  sum2_1[2] + sum2_1[3]   ;
            end 
            else begin
                sum2_2[0]               <=  sum2_2[0]               ;
                sum2_2[1]               <=  sum2_2[1]               ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            SUM2                        <=  'b0                     ;
        end 
        else begin  
            if (ena_d[6]) begin
                SUM2                    <=  sum2_2[0] + sum2_2[1]   ;
            end 
            else begin
                SUM2                    <=  SUM2                    ;
            end    
        end
    end

    wire               [  45: 0]        fifo_dout                   ;
    wire                                fifo_empty                  ;

Sync_FIFO#(
   .DATA_WIDTH     (46             ),
   .DATA_DEPTH     (16             )
)
 u_Sync_FIFO(
    .clk                                (clk                       ),// ϵͳʱ��
    .rst                                (rst                       ),// �͵�ƽ��Ч�ĸ�λ�ź�
    .data_in                            ({SUM2,SUM1_d}             ),// д�������
    .wr_en                              (ena_d[7]                  ),// дʹ���źţ��ߵ�ƽ��Ч

    .rd_en                              (rd_fifo),// ��ʹ���źţ��ߵ�ƽ��Ч
    .data_out                           (fifo_dout                 ),// ���������

    .empty                              (fifo_empty                ) // �ձ�־���ߵ�ƽ��ʾ��ǰFIFO�ѱ�д��
);

    reg                [   2: 0]        cal_cnt                     ;
    wire                                rd_fifo                     ;
    reg                                 rd_fifo_d                   ;

    assign rd_fifo = (cal_cnt < 5) && s_axis_divisor_tready && (~fifo_empty);
    
    always @(posedge clk ) 
    begin
        if (rst) begin
            cal_cnt <= 'b0;
        end 
        else begin
            if (rd_fifo && (~d_out_valid)) begin
                cal_cnt <= cal_cnt + 1;
            end
            else if (~rd_fifo && (d_out_valid)) begin
                cal_cnt <= cal_cnt - 1;
            end
            else begin
                cal_cnt <= cal_cnt;
            end
        end
    end

    always @(posedge clk ) 
    begin
        if (rst) begin
            rd_fifo_d <= 'b0;
        end else begin
            rd_fifo_d <= rd_fifo;
        end
    end

    wire                                        s_axis_divisor_tready       ;
    wire                                        s_axis_dividend_tready      ;

    Divider_18Delays u_Divider_18Delays (
    .aclk                                      (clk                        ),// input wire aclk
    .s_axis_divisor_tvalid                     (rd_fifo_d                  ),// input wire s_axis_divisor_tvalid
    .s_axis_divisor_tready                     (s_axis_divisor_tready      ),// output wire s_axis_divisor_tready

    .s_axis_divisor_tdata                      ({5'b0,fifo_dout[18:0]}     ),// input wire [7 : 0] s_axis_divisor_tdata
    .s_axis_dividend_tvalid                    (rd_fifo_d                  ),// input wire s_axis_dividend_tvalid
    .s_axis_dividend_tready                    (s_axis_dividend_tready     ),// output wire s_axis_dividend_tready
    .s_axis_dividend_tdata                     ({5'b0,fifo_dout[45:19]}    ),// input wire [15 : 0] s_axis_dividend_tdata
    .m_axis_dout_tvalid                        (d_out_valid                ),// output wire m_axis_dout_tvalid
    .m_axis_dout_tdata                         (d_out                      ) // output wire [23 : 0] m_axis_dout_tdata
    );
    

endmodule                                                          
