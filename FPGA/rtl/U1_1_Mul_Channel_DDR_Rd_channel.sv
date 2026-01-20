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
// Last modified Date:     2025/03/17 17:37:52 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/17 17:37:52 
// Version:                V1.0 
// TEXT NAME:              U3_0_Mul_Channel_DDR_Wr_channel.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U3_0_Mul_Channel_DDR_Wr_channel.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U1_0_Mul_Channel_DDR_Rd_channel(
    input                                       clk                         ,
    input                                       ui_clk                      ,
    input                                       rst                         ,
    input                                       ui_clk_sync_rst             ,

    input                                       M_rd_req      [2:0]         ,//!本地写请�??
    output  wire                                M_rd_granted  [2:0]         ,//!可接收一轮传�??
    output  wire                                M_rd_busy     [2:0]         ,//!
    input                     [  31: 0]         M_rd_len      [2:0]         ,//!写长度：单位打拍数量
    input                     [  31: 0]         M_rd_addr     [2:0]         ,//!写地�??
    output  wire              [  63: 0]         M_rd_dout     [2:0]         ,//!写数据输�??
    output  wire                                M_rd_dval     [2:0]         ,//!写数据有�??
    output  wire                                M_rd_finish   [2:0]         ,//!写完�??

//---------------------------------------------------------------------------
// output AXI4_RD                                                                        
//---------------------------------------------------------------------------
  // Master Write Address
    output   wire             [   5: 0]         M_AXI_ARID                  ,
    output   reg              [  31: 0]         M_AXI_ARADDR                ,
    output   reg              [   7: 0]         M_AXI_ARLEN                 ,
    output   wire             [   2: 0]         M_AXI_ARSIZE                ,
    output   wire             [   1: 0]         M_AXI_ARBURST               ,
    output   wire                               M_AXI_ARLOCK                ,
    output   wire             [   3: 0]         M_AXI_ARCACHE               ,
    output   wire             [   2: 0]         M_AXI_ARPROT                ,
    output   wire             [   3: 0]         M_AXI_ARQOS                 ,
    output   wire             [   1: 0]         M_AXI_ARUSER                ,
    output   reg                                M_AXI_ARVALID               ,
    input                                       M_AXI_ARREADY               ,
  // Master Write Data
    input                     [   3: 0]         M_AXI_RID                   ,
    input                     [ 255: 0]         M_AXI_RDATA                 ,
    input                     [   1: 0]         M_AXI_RRESP                 ,
    input                                       M_AXI_RLAST                 ,
    input                     [   0: 0]         M_AXI_RUSER                 ,
    input                                       M_AXI_RVALID                ,
    input                                       M_AXI_RREADY                

);

    reg                       [  19: 0]         FIFO_Transaction_Len[2:0]  ;// granted sum transaction info
    reg                       [  31: 0]         FIFO_Transaction_Addr[2:0]  ;// granted sum transaction info
    reg                       [   2: 0]         FIFO_Granted_status         ;
    reg                       [  19: 0]         FIFO_Transaction_tmp_Len[2:0]  ;// granted sum transaction info
    reg                       [  31: 0]         FIFO_Transaction_tmp_Addr[2:0]  ;// granted sum transaction info
    wire                                        grant0_d                    ;
    wire                                        grant1_d                    ;
    wire                                        grant2_d                    ;
    wire                      [   2: 0]         granted_fifo_id[2:0]  ;
    wire                                        o_dval_r                    ;
    wire                      [  63: 0]         S_wr_data                   ;
    wire                                        S_wr_dval                   ;
    wire                      [   6: 0]         fifo_cnt   [2:0]  ;
    wire                      [  63: 0]         fc_in      [2:0]  ;
    wire                      [   0: 0]         fc_in_val  [2:0]  ;
    wire                                        last_transaction[2:0]       ;
    wire                      [   2: 0]         select_mux                  ;
    wire                                        start_rd                    ;
    reg                                         transaction_finish_r        ;
    wire                                        transaction_finish          ;
    wire                      [  19: 0]         trans_cnt  [2:0]  ;
    localparam                BURST_LEN                   = 15    ;
    localparam                IDLE                        = 0     ;//start
    localparam                WAIT_RDY                    = 1     ;//wready
    localparam                PROC                        = 2     ;//wlast

    reg                       [   1: 0]         state_axi_mst               ;
    reg                       [   7: 0]         burst_cnt                   ;
    wire                      [  31: 0]         selected_addr               ;
    wire                      [   2: 0]         selected_lasttrans          ;
    wire                      [  19: 0]         select_lenth                ;

    assign                                      M_AXI_ARID         = 6'b0   ;
    assign                                      M_AXI_ARSIZE       = 3'b110 ;
    assign                                      M_AXI_ARBURST      = 2'b01  ;
    assign                                      M_AXI_ARLOCK       = 1'b0   ;
    assign                                      M_AXI_ARCACHE      = 4'b0010;
    assign                                      M_AXI_ARPROT       = 3'b000 ;
    assign                                      M_AXI_ARQOS        = 4'b0000;
    assign                                      M_AXI_ARUSER       = 2'b00  ;

//---------------------------------------------------------------------------------------
//  Reg_Pile                                                                             
//---------------------------------------------------------------------------------------


    always @(posedge clk ) begin
        if (rst) begin
            FIFO_Granted_status             <=          3'b000                            ;
        end
        else begin
            if (transaction_finish) begin
                if (last_transaction[0]) begin
                    FIFO_Granted_status[0]  <=  FIFO_Granted_status[0] & (~select_mux[0]) ;
                end
                else if (last_transaction[1]) begin
                    FIFO_Granted_status[1]  <=  FIFO_Granted_status[1] & (~select_mux[1]) ;
                end
                else begin
                    FIFO_Granted_status[2]  <=  FIFO_Granted_status[2] & (~select_mux[2]) ;
                end
            end
            else if (o_dval_r) begin
                FIFO_Granted_status         <=  FIFO_Granted_status | granted_fifo_id[0] | granted_fifo_id[1] | granted_fifo_id[2];       
            end
            else begin
                FIFO_Granted_status         <=  FIFO_Granted_status                       ;
            end
        end
    end

    genvar i ;

    generate
        for (i = 0; i < 3; i = i + 1) begin
            always @(posedge clk ) begin//这里寄存的是MM主机的号
                if (rst) begin
                    FIFO_Transaction_tmp_Addr[i]      <=      'b0                         ;
                    FIFO_Transaction_tmp_Len[i]       <=      'b0                         ;
                end 
                else begin
                    if (M_rd_req[i]) begin
                        FIFO_Transaction_tmp_Addr[i]  <=      M_rd_addr[i]                ;
                        FIFO_Transaction_tmp_Len[i]   <=      M_rd_len[i][19:0]           ;
                    end
                    else begin
                        FIFO_Transaction_tmp_Addr[i]  <=      FIFO_Transaction_tmp_Addr[i];
                        FIFO_Transaction_tmp_Len[i]   <=      FIFO_Transaction_tmp_Len[i] ;
                    end
                end
            end

            always @(posedge clk ) begin//这里寄存的是经过分配后的FIFO�??
                if (rst) begin
                    FIFO_Transaction_Len[i]           <=      'b0                         ;
                    FIFO_Transaction_Addr[i]          <=      'b0                         ;
                end 
                else begin
                    if (M_rd_granted[i]) begin
                        if (granted_fifo_id[i][0]) begin
                            FIFO_Transaction_Len[0]   <=       FIFO_Transaction_tmp_Len[i];
                            FIFO_Transaction_Addr[0]  <=       FIFO_Transaction_tmp_Addr[i];
                        end 
                        else if (granted_fifo_id[i][1]) begin
                            FIFO_Transaction_Len[1]   <=       FIFO_Transaction_tmp_Len[i];
                            FIFO_Transaction_Addr[1]  <=       FIFO_Transaction_tmp_Addr[i];
                        end
                        else begin
                            FIFO_Transaction_Len[2]   <=       FIFO_Transaction_tmp_Len[i];
                            FIFO_Transaction_Addr[2]  <=       FIFO_Transaction_tmp_Addr[i];
                        end
                    end
                    else if (transaction_finish) begin
                        if (last_transaction[i]) begin
                            FIFO_Transaction_Len[i]   <=     (select_mux[i])? 20'd0 :  FIFO_Transaction_Len[i];
                        end else begin
                            FIFO_Transaction_Len[i]   <=      FIFO_Transaction_Len[i]     ;
                        end
                    end
                    else begin
                        FIFO_Transaction_Len[i]       <=       FIFO_Transaction_Len[i]    ;
                        FIFO_Transaction_Addr[i]      <=       FIFO_Transaction_Addr[i]   ;
                    end 
                end
            end
        end
    endgenerate


//---------------------------------------------------------------------------------------
// 调度仲裁，负责给事务接口分配FC
//---------------------------------------------------------------------------------------


    U1_0_0_FIFO_Alloc_Arbitor u_U1_0_0_FIFO_Alloc_Arbitor(
        .clk                                       (clk                        ),
        .rst                                       (rst                        ),

        .req0                                      (M_rd_req[0]                ),
        .req1                                      (M_rd_req[1]                ),
        .req2                                      (M_rd_req[2]                ),

        .fifo_granted_status                       (FIFO_Granted_status        ),

        .grant0_d                                  (M_rd_granted[0]            ),
        .grant1_d                                  (M_rd_granted[1]            ),
        .grant2_d                                  (M_rd_granted[2]            ),
        .o_dval_r                                  (o_dval_r                   ),
        .granted_fifo_id                           (granted_fifo_id            ) //给每个�?�道主机分配的FIFO�??
    );


//---------------------------------------------------------------------------------------
// 全连接层
//---------------------------------------------------------------------------------------


    U1_0_1_FC#(
        .D_WIDTH                                   (64                         ),
        .FIFO_CH_NUM                               (3                          ) 
    )
     u_U1_0_1_FC(
        .clk                                       (clk                        ),
        .rst                                       (rst                        ),
        .granted_ena                               ({M_rd_granted[2],M_rd_granted[1],M_rd_granted[0]}),
        .granted_fifo_id                           (granted_fifo_id            ),
        .M_rd_din                                  (fc_in                      ),// !写数据输�??
        .M_rd_dval                                 (fc_in_val                  ),// !写数据有�??
        .S_rd_data                                 (M_rd_dout                  ),// !输出
        .S_rd_dval                                 (M_rd_dval                  ) // !输出
    );



    assign                              fifo_cnt[0]                 = 7'h10     ;
    assign                              fifo_cnt[1]                 = 7'h10     ;
    assign                              fifo_cnt[2]                 = 7'h10     ;


//---------------------------------------------------------------------------------------
//  MUX_TO_DATA_OUT                                                                                    
//---------------------------------------------------------------------------------------



    u_OneHot_1_to_3_DEMUX#(
        .D_WIDTH                                   (1                          ),
        .CH_NUM                                    (3                          ) 
    )
     u_u_OneHot_1_to_3_DEMUX_val(
        .select_info                               (select_mux                 ),
        .d_in                                      (M_AXI_RVALID               ),
        .d_out                                     (fc_in_val                  ) 
    );


    u_OneHot_1_to_3_DEMUX#(
        .D_WIDTH                                   (64                         ),
        .CH_NUM                                    (3                          ) 
    )
    u_u_OneHot_1_to_3_DEMUX_data(
        .select_info                               (select_mux                 ),
        .d_in                                      (M_AXI_RDATA                ),
        .d_out                                     (fc_in                      ) 
    );


//---------------------------------------------------------------------------------------
// 时序启动与FIFO选取的仲裁模�??1
//---------------------------------------------------------------------------------------


    U1_0_3_Transaction_Arbitor#(
        .FIFO_CH_NUM                               (3                          ) 
    )
    u_U1_0_3_Transaction_Arbitor(
        .clk                                       (ui_clk                        ),
        .rst                                       (ui_clk_sync_rst                        ),

        .FIFO_lenth                                (FIFO_Transaction_Len       ),// 系统信息
        .FIFO_granted                              (FIFO_Granted_status        ),// 系统信息
        .FIFO_stack_cnt                            (fifo_cnt                   ),
        .trans_cnt                                 (trans_cnt                  ),

        .last_transaction                          (last_transaction           ),
        .select_mux                                (select_mux                 ),//选择FIFO
        .start_wr                                  (start_rd                   ),
        .transaction_finish                        (transaction_finish         ) //input
    );


//---------------------------------------------------------------------------------------
// 时序发生�??                                                                                    
//---------------------------------------------------------------------------------------


    
    assign selected_addr =   (select_mux[0])? FIFO_Transaction_Addr[0] + trans_cnt[0] 
                            :(select_mux[1])? FIFO_Transaction_Addr[1] + trans_cnt[1]
                            :(select_mux[2])? FIFO_Transaction_Addr[2] + trans_cnt[2]
                            : 'b0;
    
    assign select_trans_cnt = (select_mux[0])? trans_cnt[0]
                             :(select_mux[1])? trans_cnt[1]
                             :(select_mux[2])? trans_cnt[2]
                             : 'b0;
    
    assign select_lenth =    (select_mux[0])? FIFO_Transaction_Len[0]
                            :(select_mux[1])? FIFO_Transaction_Len[1]
                            :(select_mux[2])? FIFO_Transaction_Len[2]
                            : 'b0;
    
    assign selected_lasttrans =  (select_mux[0])? last_transaction[0]
                                :(select_mux[1])? last_transaction[1]
                                :(select_mux[2])? last_transaction[2]
                                : 1'b0;



    always @(posedge ui_clk )
    begin
        if (ui_clk_sync_rst) begin
            state_axi_mst               <=      IDLE                ;
            transaction_finish_r        <=      1'b0                ;
            M_AXI_ARADDR                <=       'b0                ;
            M_AXI_ARLEN                 <=       'b0                ;
            M_AXI_ARVALID               <=       'b0                ;
        end 
        else begin
            case (state_axi_mst)
                IDLE    : begin
                    transaction_finish_r<=      1'b0                ;
                    if (start_rd) begin
                        state_axi_mst   <=      WAIT_RDY            ;
                        M_AXI_ARADDR    <=      selected_addr       ;
                        M_AXI_ARVALID   <=      1'b1                ;
                        if (selected_lasttrans) begin
                            M_AXI_ARLEN <=      (select_lenth >> 3) - select_trans_cnt;
                        end else begin
                            M_AXI_ARLEN <=      BURST_LEN           ;
                        end
                    end else begin
                        state_axi_mst   <=      IDLE                ;
                    end
                end
                WAIT_RDY: begin
                    if (M_AXI_ARREADY) begin
                        state_axi_mst   <=      PROC                ;
                        M_AXI_ARVALID   <=      1'b0                ;
                    end else begin
                        state_axi_mst   <=      WAIT_RDY            ;
                    end
                end
                PROC    : begin
                    if (M_AXI_RLAST) begin
                        state_axi_mst   <=      IDLE                ;
                        transaction_finish_r <= 1'b1                ;
                    end else begin
                        state_axi_mst   <=      PROC                ;
                    end
                end
                default : begin
                    state_axi_mst       <=      IDLE                ;
                end
            endcase
        end
    end

    always @(posedge ui_clk ) begin
        if (ui_clk_sync_rst) begin
            burst_cnt                   <=      'b0                 ;
        end 
        else begin
            if (state_axi_mst == PROC) begin
                if (M_AXI_RREADY & M_AXI_RVALID) begin
                    if (burst_cnt == BURST_LEN) begin
                        burst_cnt       <=      'b0                 ;
                    end 
                    else begin
                        burst_cnt       <=      burst_cnt + 1       ;
                    end
                end
                else begin
                    burst_cnt           <=      burst_cnt           ;
                end
            end 
            else begin
                burst_cnt               <=      'b0                 ;
            end
        end
    end


    U0_SinglePulse u_U0_finish_pulse(
        .clk                            (ui_clk                       ),
        .rst                            (ui_clk_sync_rst                       ),
        .pos_dir                        (transaction_finish_r      ),
        .pos_pulse                      (transaction_finish        ) 
    );


endmodule                                                          
                                                  
