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

module U1_0_Mul_Channel_DDR_Wr_channel(
    input                                       clk                         ,
    input                                       ui_clk                      ,
    input                                       rst                         ,
    input                                       ui_clk_sync_rst             ,

    input                                       M_wr_req      [2:0]         ,//!閺堫剙婀撮崘娆掝嚞閿燂拷?
    output  wire                                M_wr_granted  [2:0]         ,//!閸欘垱甯撮弨鏈电鏉烆喕绱堕敓锟�?
    output  wire                                M_wr_busy     [2:0]         ,
    input                     [  31: 0]         M_wr_len      [2:0]         ,//!閸愭瑩鏆辨惔锔肩窗閸楁洑缍呴幍鎾村閺佷即鍣�
    input                     [  31: 0]         M_wr_addr     [2:0]         ,//!閸愭瑥婀撮敓锟�?
    input                     [  63: 0]         M_wr_din      [2:0]         ,//!閸愭瑦鏆熼幑顔跨翻閿燂拷?
    input                                       M_wr_dval     [2:0]         ,//!閸愭瑦鏆熼幑顔芥箒閿燂拷?
    input                                       M_wr_finish   [2:0]         ,//!閸愭瑥鐣敓锟�?


//---------------------------------------------------------------------------
// output AXI4_WR                                                                        
//---------------------------------------------------------------------------
  // Master Write Address
    output   wire             [   5: 0]         M_AXI_AWID                  ,
    output   reg              [  31: 0]         M_AXI_AWADDR                ,
    output   reg              [   7: 0]         M_AXI_AWLEN                 ,
    output   wire             [   2: 0]         M_AXI_AWSIZE                ,
    output   wire             [   1: 0]         M_AXI_AWBURST               ,
    output   wire                               M_AXI_AWLOCK                ,
    output   wire             [   3: 0]         M_AXI_AWCACHE               ,
    output   wire             [   2: 0]         M_AXI_AWPROT                ,
    output   wire             [   3: 0]         M_AXI_AWQOS                 ,
    output   wire             [   1: 0]         M_AXI_AWUSER                ,
    output   reg                                M_AXI_AWVALID               ,
    input                                       M_AXI_AWREADY               ,
  // Master Write Data
    output   wire             [ 255: 0]         M_AXI_WDATA                 ,
    output   wire             [   7: 0]         M_AXI_WSTRB                 ,

    output   wire                               M_AXI_WLAST                 ,
    output   wire             [   0: 0]         M_AXI_WUSER                 ,
    output   wire                               M_AXI_WVALID                ,
    input                                       M_AXI_WREADY                ,

  // Master Write Response
    input                     [   0: 0]         M_AXI_BID                   ,
    input                     [   1: 0]         M_AXI_BRESP                 ,
    input                     [   0: 0]         M_AXI_BUSER                 ,
    input                                       M_AXI_BVALID                ,
    output   reg                                M_AXI_BREADY                

);

    localparam                BURST_LEN                   = 15    ;
    localparam                IDLE                        = 0     ;//start
    localparam                WAIT_RDY                    = 1     ;//wready
    localparam                PROC                        = 2     ;//wlast
    localparam                WAIT_RES                    = 3     ;//bresp & bvalid & bready

    reg                       [   1: 0]         state_axi_mst               ;
    reg                       [   7: 0]         burst_cnt                   ;
    wire                      [  31: 0]         selected_addr               ;
    wire                      [   2: 0]         selected_lasttrans          ;
    wire                      [  19: 0]         select_lenth                ;
    wire                                        last_transaction[2:0]       ;
    wire                      [   2: 0]         select_mux                  ;
    wire                                        start_wr                    ;
    reg                                         transaction_finish_r        ;
    wire                                        transaction_finish          ;
    wire                      [  19: 0]         trans_cnt  [2:0]            ;
    wire                      [   6: 0]         fifo_cnt   [2:0]            ;
    wire                                        rd_ena     [2:0]            ;
    wire                      [  63: 0]         rd_data    [2:0]            ;
    wire                      [  63: 0]         S_wr_data  [2:0]            ;
    wire                                        S_wr_dval  [2:0]            ;
    wire                                        grant0_d                    ;
    wire                                        grant1_d                    ;
    wire                                        grant2_d                    ;
    wire                      [   2: 0]         granted_fifo_id[2:0]        ;
    wire                                        o_dval_r                    ;

    reg                       [  19: 0]         FIFO_Transaction_Len[2:0]   ;// granted sum transaction info
    reg                       [  31: 0]         FIFO_Transaction_Addr[2:0]  ;// granted sum transaction info
    reg                       [   2: 0]         FIFO_Granted_status         ;
    reg                       [  19: 0]         FIFO_Transaction_tmp_Len[2:0]  ;// granted sum transaction info
    reg                       [  31: 0]         FIFO_Transaction_tmp_Addr[2:0]  ;// granted sum transaction info


    assign                                      M_AXI_AWID         = 6'b0   ;
    assign                                      M_AXI_AWSIZE       = 3'b110 ;
    assign                                      M_AXI_AWBURST      = 2'b01  ;
    assign                                      M_AXI_AWLOCK       = 1'b0   ;
    assign                                      M_AXI_AWCACHE      = 4'b0010;
    assign                                      M_AXI_AWPROT       = 3'b000 ;
    assign                                      M_AXI_AWQOS        = 4'b0000;
    assign                                      M_AXI_WSTRB        = 8'hff  ;
    assign                                      M_AXI_WVALID       = (state_axi_mst == PROC) & M_AXI_WREADY;
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
            always @(posedge clk ) begin//鏉╂瑩鍣风€靛嫬鐡ㄩ惃鍕ЦMM娑撶粯婧€閻ㄥ嫬褰�
                if (rst) begin
                    FIFO_Transaction_tmp_Addr[i]      <=      'b0                         ;
                    FIFO_Transaction_tmp_Len[i]       <=      'b0                         ;
                end 
                else begin
                    if (M_wr_req[i]) begin
                        FIFO_Transaction_tmp_Addr[i]  <=      M_wr_addr[i]                ;
                        FIFO_Transaction_tmp_Len[i]   <=      M_wr_len[i][19:0]                 ;
                    end
                    else begin
                        FIFO_Transaction_tmp_Addr[i]  <=      FIFO_Transaction_tmp_Addr[i];
                        FIFO_Transaction_tmp_Len[i]   <=      FIFO_Transaction_tmp_Len[i][19:0] ;
                    end
                end
            end

            always @(posedge clk ) begin//鏉╂瑩鍣风€靛嫬鐡ㄩ惃鍕Ц缂佸繗绻冮崚鍡涘帳閸氬海娈慒IFO閿燂拷?
                if (rst) begin
                    FIFO_Transaction_Len[i]           <=      'b0                         ;
                    FIFO_Transaction_Addr[i]          <=      'b0                         ;
                end 
                else begin
                    if (M_wr_granted[i]) begin
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
// FIFO鐠嬪啫瀹虫禒鑼额梿閿涘矁绀嬬拹锝囩舶娴滃濮熼幒銉ュ經閸掑棝鍘IFO
//---------------------------------------------------------------------------------------

    U1_0_0_FIFO_Alloc_Arbitor u_U1_0_0_FIFO_Alloc_Arbitor(
        .clk                                       (clk                        ),
        .rst                                       (rst                        ),

        .req0                                      (M_wr_req[0]                ),
        .req1                                      (M_wr_req[1]                ),
        .req2                                      (M_wr_req[2]                ),

        .fifo_granted_status                       (FIFO_Granted_status        ),

        .grant0_d                                  (M_wr_granted[0]            ),
        .grant1_d                                  (M_wr_granted[1]            ),
        .grant2_d                                  (M_wr_granted[2]            ),
        .o_dval_r                                  (o_dval_r                   ),
        .granted_fifo_id                           (granted_fifo_id            ) //缂佹瑦鐦℃稉顏庢嫹?閿熶粙浜炬稉缁樻簚閸掑棝鍘ら惃鍑FO閿燂拷?
    );

    U1_0_1_FC#(
        .D_WIDTH                                   (64                         ),
        .FIFO_CH_NUM                               (3                          ) 
    )
     u_U1_0_1_FC(
        .clk                                       (clk                        ),
        .rst                                       (rst                        ),
        .granted_ena                               ({M_wr_granted[2],M_wr_granted[1],M_wr_granted[0]}),
        .granted_fifo_id                           (granted_fifo_id            ),
        .M_wr_din                                  (M_wr_din                   ),// !閸愭瑦鏆熼幑顔跨翻閿燂拷?
        .M_wr_dval                                 (M_wr_dval                  ),// !閸愭瑦鏆熼幑顔芥箒閿燂拷?
        .S_wr_data                                 (S_wr_data                  ),
        .S_wr_dval                                 (S_wr_dval                  ) //缂佹IFO閻ㄥ嫯绶崗銉ゅ▏閿燂拷?
    );


    U1_0_2_FIFO_Stack#(
        .D_WIDTH                                   (64                         ),
        .D_DEPTH                                   (128                        ),
        .FIFO_CH_NUM                               (3                          ) 
    )
    u_U1_0_2_FIFO_Stack(
        .clk                                       (clk                        ),
        .rst                                       (rst                        ),
        .wr_ena                                    (S_wr_dval                  ),
        .wr_data                                   (S_wr_data                  ),
        .fifo_cnt                                  (fifo_cnt                   ),
        .rd_ena                                    (rd_ena                     ),
        .rd_data                                   (rd_data                    ) 
    );

//---------------------------------------------------------------------------------------
//  MUX_TO_DATA_OUT                                                                                    
//---------------------------------------------------------------------------------------


    u_OneHot_3_to_1_MUX#(
        .D_WIDTH                                   (64                         ),
        .FIFO_CH_NUM                               (3                          ) 
    )
     u_u_OneHot_3_to_1_MUX(
        .select_info                               (select_mux                 ),
        .d_in                                      (rd_data                    ),
        .d_out                                     (M_AXI_WDATA                ) //閿燂拷?缂佸牏娈戞潏鎾冲毉
    );

    u_OneHot_1_to_3_DEMUX#(
        .D_WIDTH                                   (1                          ),
        .CH_NUM                                    (3                          ) 
    )
     u_u_OneHot_1_to_3_DEMUX(
        .select_info                               (select_mux                 ),
        .d_in                                      (M_AXI_WVALID               ),
        .d_out                                     (rd_ena                     ) 
    );


//---------------------------------------------------------------------------------------
// 閺冭泛绨崥顖氬З娑撳锭IFO闁褰囬惃鍕緤鐟佷焦膩閿燂拷?1
//---------------------------------------------------------------------------------------


    U1_0_3_Transaction_Arbitor#(
        .FIFO_CH_NUM                               (3                          ) 
    )
    u_U1_0_3_Transaction_Arbitor(
        .clk                                       (ui_clk                     ),
        .rst                                       (ui_clk_sync_rst            ),

        .FIFO_lenth                                (FIFO_Transaction_Len       ),// 缁崵绮烘穱鈩冧紖
        .FIFO_granted                              (FIFO_Granted_status        ),// 缁崵绮烘穱鈩冧紖
        .FIFO_stack_cnt                            (fifo_cnt                   ),
        .trans_cnt                                 (trans_cnt                  ),

        .last_transaction                          (last_transaction           ),
        .select_mux                                (select_mux                 ),//闁瀚‵IFO
        .start_wr                                  (start_wr                   ),
        .transaction_finish                        (transaction_finish         ) //input
    );


//---------------------------------------------------------------------------------------
// 閺冭泛绨崣鎴犳晸閿燂拷?                                                                                    
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
            M_AXI_AWADDR                <=       'b0                ;
            M_AXI_AWLEN                 <=       'b0                ;
            M_AXI_AWVALID               <=       'b0                ;
            M_AXI_BREADY                <=      1'b0                ;
        end 
        else begin
            case (state_axi_mst)
                IDLE    : begin
                    transaction_finish_r<=      1'b0                ;

                    if (start_wr) begin
                        state_axi_mst   <=      WAIT_RDY            ;
                        M_AXI_AWADDR    <=      selected_addr       ;
                        M_AXI_AWVALID   <=      1'b1                ;
                        if (selected_lasttrans) begin
                            M_AXI_AWLEN <=      (select_lenth >> 3) - select_trans_cnt;
                        end else begin
                            M_AXI_AWLEN <=      BURST_LEN           ;
                        end
                    end else begin
                        state_axi_mst   <=      IDLE                ;
                    end
                end
                WAIT_RDY: begin
                    if (M_AXI_AWREADY) begin
                        state_axi_mst   <=      PROC                ;
                        M_AXI_AWVALID   <=      1'b0                ;
                        M_AXI_BREADY    <=      1'b1                ;
                    end else begin
                        state_axi_mst   <=      WAIT_RDY            ;
                    end
                end
                PROC    : begin
                    if ((burst_cnt == BURST_LEN) & M_AXI_WREADY) begin
                        state_axi_mst   <=      WAIT_RES            ;
                    end else begin
                        state_axi_mst   <=      PROC                ;
                    end
                end
                WAIT_RES: begin
                    if ((M_AXI_BRESP == 2'b00) & M_AXI_BVALID & M_AXI_BREADY) begin
                        state_axi_mst   <=      IDLE                ;
                        M_AXI_BREADY    <=      1'b0                ;
                        transaction_finish_r <= 1'b1                ;
                    end else begin
                        state_axi_mst   <=      WAIT_RES            ;
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
                if (M_AXI_WREADY) begin
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
    .clk                                       (ui_clk                     ),
    .rst                                       (ui_clk_sync_rst            ),
    .pos_dir                                   (transaction_finish_r       ),
    .pos_pulse                                 (transaction_finish         ) 
    );


endmodule                                                          
