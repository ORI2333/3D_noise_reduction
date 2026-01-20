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
// Last modified Date:     2025/03/20 16:00:58 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/20 16:00:58 
// Version:                V1.0 
// TEXT NAME:              U1_0_3_Transaction_Arbitor.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U1_0_3_Transaction_Arbitor.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U1_0_3_Transaction_Arbitor #(
    parameter                 FIFO_CH_NUM                 = 3     
)(
    input                                       clk                         ,
    input                                       rst                         ,

    input                     [  19: 0]         FIFO_lenth[FIFO_CH_NUM-1:0] ,//系统信息
    input                     [   2: 0]         FIFO_granted                ,//系统信息
    input                     [   6: 0]         FIFO_stack_cnt[FIFO_CH_NUM-1:0],
    output wire               [  19: 0]         trans_cnt     [FIFO_CH_NUM-1:0],

    output wire                                 last_transaction[FIFO_CH_NUM-1:0],
    output reg                [   2: 0]         select_mux                  ,
    output wire                                 start_wr                    ,
    input                                       transaction_finish        

);

    localparam                IDLE                                  = 0     ;
    localparam                JUDGE                                 = 1     ;
    localparam                PROC                                  = 2     ;

    reg                                         start_wr_r                  ;
    reg                                         start_arb_r                 ;
    reg                       [   1: 0]         state_r                     ;

    wire                      [FIFO_CH_NUM-1: 0]Select_FIFO_id              ;
    wire                                        Arbitor_flag                ;

U0_SinglePulse_SubSys u_U0_SinglePulse_SubSys(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .pos_dir0                                  (start_wr_r                 ),
    .pos_dir1                                  (start_arb_r                ),
    .pos_pulse0                                (start_wr                   ),
    .pos_pulse1                                (start_arb                  )
);

    wire                      [   9: 0]         FIFO_MAX_Condition          ;

    assign FIFO_MAX_Condition = FIFO_stack_cnt[0] | FIFO_stack_cnt[1] | FIFO_stack_cnt[2];

    wire                                        MAX_FIFO_can_trans          ;

    assign MAX_FIFO_can_trans = (FIFO_MAX_Condition[9:4] >= 6'b000001)      ; 


//---------------------------------------------------------------------------------------
// fsm                                                                                    
//---------------------------------------------------------------------------------------

    always @(posedge clk ) 
    begin
        if (rst) begin
            state_r          <=      IDLE                ;
        end 
        else begin
            case (state_r)
            IDLE : begin
                if ((|FIFO_granted) && MAX_FIFO_can_trans) begin
                    state_r  <=      JUDGE                ;
                end 
                else begin
                    state_r  <=      IDLE                ;
                end 
            end
            JUDGE  : begin
                if (Arbitor_flag) begin
                 state_r     <=      PROC                ;
                end
                else begin
                 state_r     <=      JUDGE               ;
                end 
            end     
            PROC   : begin
                if (transaction_finish) begin
                    state_r  <=      IDLE                ;       
                end 
                else begin
                    state_r  <=      PROC                ;
                end
            end     
    
            default: begin
                state_r      <=     IDLE                 ;
            end      
            endcase
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            start_arb_r      <=    1'b0                 ;
        end 
        else begin
            if ((|FIFO_granted) && (state_r == IDLE) && (MAX_FIFO_can_trans)) begin
                start_arb_r  <=    1'b1                 ;
            end else begin
                start_arb_r  <=    1'b0                 ;     
            end
        end
    end


    always @(posedge clk ) 
    begin
        if (rst) begin
            select_mux       <=    3'b000               ;
            start_wr_r       <=    1'b0                 ;
        end else begin
            if (Arbitor_flag) begin
                select_mux   <=    Select_FIFO_id       ;
                start_wr_r   <=    1'b1                 ;
            end else begin
                select_mux   <=    select_mux           ;
                start_wr_r   <=    1'b0                 ;
            end
        end
    end

//---------------------------------------------------------------------------------------
//                                                                                     
//---------------------------------------------------------------------------------------

    U1_0_3_0_Tran_Arbitor#(//通过ena信号实时调整权�?�，随后输出单次传输的FIFO号，指示MUX选路然后生成时序
    .CH_NUM                                    (3                          ),
    .ONCE_LENTH                                (16                         ) 
    )
    u_U1_0_3_0_Tran_Arbitor(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .start                                     (start_arb                  ),// 每更新一次grant信号之后就会start�?�?
    .trans_lenth                               (FIFO_lenth                 ),// 定�??
    .FIFO_stack_cnt                            (FIFO_stack_cnt             ),// 动�??
    .trans_cnt                                 (trans_cnt                  ),
    .FIFO_granted                              (FIFO_granted               ),
    .last_transaction                          (last_transaction           ),// 动�?�，指示外部等finish后挂断granted信号
    .trans_finish                              ({3{transaction_finish}}    ),// 外部的传输结束信�?
    .Select_FIFO_id                            (Select_FIFO_id             ),
    .Arbitor_flag                              (Arbitor_flag               ) // 表示本次仲裁有结果了
    );


//---------------------------------------------------------------------------------------
//
//---------------------------------------------------------------------------------------


endmodule                                                          
