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

    input                                       M_wr_req      [2:0]         ,//!闁哄牜鍓欏﹢鎾礃濞嗘帩鍤為柨鐕傛嫹?
    output  wire                                M_wr_granted  [2:0]         ,//!闁告瑯鍨辩敮鎾绩閺堢數顏遍弶鐑嗗枙缁卞爼鏁撻敓锟?
    output  wire                                M_wr_busy     [2:0]         ,
    input                     [  31: 0]         M_wr_len      [2:0]         ,//!闁告劖鐟╅弳杈ㄦ償閿旇偐绐楅柛妤佹磻缂嶅懘骞嶉幘鏉戭€為柡浣峰嵆閸ｏ拷
    input                     [  31: 0]         M_wr_addr     [2:0]         ,//!闁告劖鐟ュ﹢鎾晸閿燂拷?
    input                     [  63: 0]         M_wr_din      [2:0]         ,//!闁告劖鐟﹂弳鐔煎箲椤旇法缈婚柨鐕傛嫹?
    input                                       M_wr_dval     [2:0]         ,//!闁告劖鐟﹂弳鐔煎箲椤旇姤绠掗柨鐕傛嫹?
    input                                       M_wr_finish   [2:0]         ,//!闁告劖鐟ラ悾顒勬晸閿燂拷?


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
    wire                      [  63: 0]         M_AXI_WDATA_64              ;
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
    assign                                      M_AXI_WDATA        = {192'b0, M_AXI_WDATA_64};
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
            always @(posedge clk ) begin//閺夆晜鐟╅崳椋庘偓闈涘閻°劑鎯冮崟顒佇M濞戞挾绮┃鈧柣銊ュ瑜帮拷
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

            end
    endgenerate

    // FIFO slot-centric: each FIFO_Transaction_Addr/Len[j] driven by exactly one always block
    genvar j ;
    generate
        for (j = 0; j < 3; j = j + 1) begin : gen_fifo_slot
            always @(posedge clk) begin
                if (rst) begin
                    FIFO_Transaction_Len[j]           <=      'b0                         ;
                    FIFO_Transaction_Addr[j]          <=      'b0                         ;
                end
                else begin
                    if      (M_wr_granted[0] && granted_fifo_id[0][j]) begin
                        FIFO_Transaction_Len[j]       <=       FIFO_Transaction_tmp_Len[0];
                        FIFO_Transaction_Addr[j]      <=       FIFO_Transaction_tmp_Addr[0];
                    end
                    else if (M_wr_granted[1] && granted_fifo_id[1][j]) begin
                        FIFO_Transaction_Len[j]       <=       FIFO_Transaction_tmp_Len[1];
                        FIFO_Transaction_Addr[j]      <=       FIFO_Transaction_tmp_Addr[1];
                    end
                    else if (M_wr_granted[2] && granted_fifo_id[2][j]) begin
                        FIFO_Transaction_Len[j]       <=       FIFO_Transaction_tmp_Len[2];
                        FIFO_Transaction_Addr[j]      <=       FIFO_Transaction_tmp_Addr[2];
                    end
                    else if (transaction_finish) begin
                        if (last_transaction[j]) begin
                            FIFO_Transaction_Len[j]   <=     (select_mux[j])? 20'd0 :  FIFO_Transaction_Len[j];
                        end else begin
                            FIFO_Transaction_Len[j]   <=      FIFO_Transaction_Len[j]     ;
                        end
                        FIFO_Transaction_Addr[j]      <=       FIFO_Transaction_Addr[j]   ;
                    end
                    else begin
                        FIFO_Transaction_Len[j]       <=       FIFO_Transaction_Len[j]    ;
                        FIFO_Transaction_Addr[j]      <=       FIFO_Transaction_Addr[j]   ;
                    end
                end
            end
        end
    endgenerate


//---------------------------------------------------------------------------------------
// FIFO閻犲鍟€硅櫕绂掗懠棰濇⒖闁挎稑鐭佺粈瀣嫻閿濆洨鑸跺ù婊冾儏婵喖骞掗妷銉ョ稉闁告帒妫濋崢顥琁FO
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
        .granted_fifo_id                           (granted_fifo_id            ) //缂備焦鐟﹂惁鈩冪▔椤忓孩瀚?闁跨喍绮欐禍鐐▔缂佹ɑ绨氶柛鎺戞閸樸倝鎯冮崙顢疐O闁跨噦鎷?
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
        .M_wr_din                                  (M_wr_din                   ),// !闁告劖鐟﹂弳鐔煎箲椤旇法缈婚柨鐕傛嫹?
        .M_wr_dval                                 (M_wr_dval                  ),// !闁告劖鐟﹂弳鐔煎箲椤旇姤绠掗柨鐕傛嫹?
        .S_wr_data                                 (S_wr_data                  ),
        .S_wr_dval                                 (S_wr_dval                  ) //缂備焦顮€IFO闁汇劌瀚欢顓㈠礂閵夈倕鈻忛柨鐕傛嫹?
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
                .d_out                                     (M_AXI_WDATA_64             ) //闁跨噦鎷?缂備礁鐗忓▓鎴炴綇閹惧啿姣?
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
// 闁哄啳娉涚花顓㈠触椤栨艾袟濞戞挸閿璉FO闂侇偄顦ぐ鍥儍閸曨亜绶ら悷浣风劍鑶╅柨鐕傛嫹?1
//---------------------------------------------------------------------------------------


    U1_0_3_Transaction_Arbitor#(
        .FIFO_CH_NUM                               (3                          ) 
    )
    u_U1_0_3_Transaction_Arbitor(
        .clk                                       (ui_clk                     ),
        .rst                                       (ui_clk_sync_rst            ),

        .FIFO_lenth                                (FIFO_Transaction_Len       ),// 缂侇垵宕电划鐑樼┍閳╁啩绱?
        .FIFO_granted                              (FIFO_Granted_status        ),// 缂侇垵宕电划鐑樼┍閳╁啩绱?
        .FIFO_stack_cnt                            (fifo_cnt                   ),
        .trans_cnt                                 (trans_cnt                  ),

        .last_transaction                          (last_transaction           ),
        .select_mux                                (select_mux                 ),//闂侇偄顦扮€氣€礗FO
        .start_wr                                  (start_wr                   ),
        .transaction_finish                        (transaction_finish         ) //input
    );


//---------------------------------------------------------------------------------------
// 闁哄啳娉涚花顓㈠矗閹寸姵鏅搁柨鐕傛嫹?                                                                                    
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

