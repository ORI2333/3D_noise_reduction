
module DDD_Noise_8CH #(
    parameter                           DDR_BASE_ADDR              = 0     ,
    parameter                           DATA_CHANNEL               = 8     ,
    parameter                           WAIT                       = 10    ,
    parameter                           CMOS_H_PIXEL               = 640   ,
    parameter                           CMOS_V_PIXEL               = 480   ,
    parameter                           H_DISP                     = 480   ,
    parameter                           V_DISP                     = 320   ,
    parameter                           MACROBLOCK_THREASHOLD      = 4095  ,
    parameter                           TEMPORAL_CALCULATE_PARAM   = 16     
)
(

    input                                       clk                         ,
    input                                       ui_clk                      ,
    input                                       rst_n                       ,
    input                                       ui_clk_sync_rst             ,

    input                     [   7: 0]         i_data_R [DATA_CHANNEL-1:0] ,
    input                     [   7: 0]         i_data_G [DATA_CHANNEL-1:0] ,
    input                     [   7: 0]         i_data_B [DATA_CHANNEL-1:0] ,

    input                                       i_fval                      ,
    input                                       i_lval                      ,


    output wire                                 o_fval                      ,
    output wire                                 o_lval                      ,
    output wire               [   7: 0]         o_data_R [DATA_CHANNEL-1:0] ,
    output wire               [   7: 0]         o_data_G [DATA_CHANNEL-1:0] ,
    output wire               [   7: 0]         o_data_B [DATA_CHANNEL-1:0] ,

    output wire               [   5: 0]         M_AXI_AWID                  ,
    output wire               [  31: 0]         M_AXI_AWADDR                ,
    output wire               [   7: 0]         M_AXI_AWLEN                 ,
    output wire               [   2: 0]         M_AXI_AWSIZE                ,
    output wire               [   1: 0]         M_AXI_AWBURST               ,
    output wire                                 M_AXI_AWLOCK                ,
    output wire               [   3: 0]         M_AXI_AWCACHE               ,
    output wire               [   2: 0]         M_AXI_AWPROT                ,
    output wire               [   3: 0]         M_AXI_AWQOS                 ,
    output wire               [   1: 0]         M_AXI_AWUSER                ,
    output wire                                 M_AXI_AWVALID               ,
    input                                       M_AXI_AWREADY               ,
  
    output wire               [ 255: 0]         M_AXI_WDATA                 ,
    output wire               [   7: 0]         M_AXI_WSTRB                 ,

    output wire                                 M_AXI_WLAST                 ,
    output wire               [   0: 0]         M_AXI_WUSER                 ,
    output wire                                 M_AXI_WVALID                ,
    input                                       M_AXI_WREADY                ,

  
    input                     [   0: 0]         M_AXI_BID                   ,
    input                     [   1: 0]         M_AXI_BRESP                 ,
    input                     [   0: 0]         M_AXI_BUSER                 ,
    input                                       M_AXI_BVALID                ,
    output wire                                 M_AXI_BREADY                ,
    
    output wire               [   5: 0]         M_AXI_ARID                  ,
    output wire               [  31: 0]         M_AXI_ARADDR                ,
    output wire               [   7: 0]         M_AXI_ARLEN                 ,
    output wire               [   2: 0]         M_AXI_ARSIZE                ,
    output wire               [   1: 0]         M_AXI_ARBURST               ,
    output wire                                 M_AXI_ARLOCK                ,
    output wire               [   3: 0]         M_AXI_ARCACHE               ,
    output wire               [   2: 0]         M_AXI_ARPROT                ,
    output wire               [   3: 0]         M_AXI_ARQOS                 ,
    output wire               [   1: 0]         M_AXI_ARUSER                ,
    output wire                                 M_AXI_ARVALID               ,
    input                                       M_AXI_ARREADY               ,
  
    input                     [   3: 0]         M_AXI_RID                   ,
    input                     [ 255: 0]         M_AXI_RDATA                 ,
    input                     [   1: 0]         M_AXI_RRESP                 ,
    input                                       M_AXI_RLAST                 ,
    input                     [   0: 0]         M_AXI_RUSER                 ,
    input                                       M_AXI_RVALID                ,
    input                                       M_AXI_RREADY                 
);

    localparam                IMAGE_DISP_SIZE             = V_DISP * H_DISP                 ;

    localparam                R_MATCH_ADDR                = DDR_BASE_ADDR + 32'h0000_0000   ;
    localparam                R_PROC_ADDR                 = DDR_BASE_ADDR + 32'h8000_0000   ;
    localparam                G_MATCH_ADDR                = DDR_BASE_ADDR + 32'h0100_0000   ;
    localparam                G_PROC_ADDR                 = DDR_BASE_ADDR + 32'h8100_0000   ;
    localparam                B_MATCH_ADDR                = DDR_BASE_ADDR + 32'h0200_0000   ;
    localparam                B_PROC_ADDR                 = DDR_BASE_ADDR + 32'h8200_0000   ;

    
    localparam                IDLE                        = 3'b000          ; 
    localparam                FIRST_FRAME                 = 3'b001          ; 
    localparam                SECOND_FRAME                = 3'b011          ; 
    localparam                INIT_LOCAL_MAT              = 3'b010          ; 
    localparam                INIT_LOCAL_PROC             = 3'b110          ; 
    localparam                ME_TD                       = 3'b111          ; 
    localparam                ALGO                        = 3'b101          ; 

    wire                     rst                              ;
    reg                                         status_wr_finish[2:0]       ;
    wire                                        wr_finish_clr               ;

    reg                       [$clog2(V_DISP)-1: 0]         line_cnt        ;
    reg                       [$clog2(H_DISP)-1: 0]         col_cnt         ;

    reg                       [  31: 0]         frame_wr_addr[2:0]          ;
    wire                      [  31: 0]         frame_proc_addr[2:0]        ;
    wire                      [  31: 0]         frame_match_addr[2:0]       ;
    wire                      [  63: 0]         data_flatten[2:0]           ;
    wire                                        wr_mux_sel                  ;
    wire                                        rd_mux_sel                  ;
    
    wire                                        M_wr_req       [2:0]        ;
    wire                                        M_wr_granted   [2:0]        ;
    wire                                        M_wr_busy      [2:0]        ;
    wire                      [  31: 0]         M_wr_len       [2:0]        ;
    wire                      [  31: 0]         M_wr_addr      [2:0]        ;
    wire                      [  63: 0]         M_wr_din       [2:0]        ;
    wire                                        M_wr_dval      [2:0]        ;
    wire                                        M_wr_finish    [2:0]        ;

    wire                                        M_rd_req       [2:0]        ;
    wire                                        M_rd_granted   [2:0]        ;
    wire                                        M_rd_busy      [2:0]        ;
    wire                      [  31: 0]         M_rd_addr      [2:0]        ;
    wire                      [  31: 0]         M_rd_lenth     [2:0]        ;
    wire                      [  63: 0]         M_rd_dout      [2:0]        ;
    wire                                        M_rd_dval      [2:0]        ;
    wire                                        M_rd_finish    [2:0]        ;
    wire                      [  63: 0]         DEMUX_rdout0   [2:0]        ;

    wire                      [   2: 0]         data_valid                  ;
    wire                      [   7: 0]         data_in  [2:0][7:0]         ;
    wire                      [  11: 0]         R_MB_dout   [1:0]           ;
    wire                                        R_MB_ena                    ;
    wire                      [  11: 0]         B_MB_dout   [1:0]           ;
    wire                                        B_MB_ena                    ;
    wire                      [  11: 0]         G_MB_dout   [1:0]           ;
    wire                                        G_MB_ena                    ;
    wire                      [  11: 0]         R_Sub_dout                  ;
    wire                                        R_Sub_ena                   ;
    wire                      [  11: 0]         G_Sub_dout                  ;
    wire                                        G_Sub_ena                   ;
    wire                      [  11: 0]         B_Sub_dout                  ;
    wire                                        B_Sub_ena                   ;

    wire                      [  11: 0]         MB_dout     [2:0][1:0]      ;
    wire                                        MB_ena      [2:0]           ;
    wire                      [  11: 0]         Sub_dout    [2:0]           ;
    wire                                        Sub_ena     [2:0]           ;


    wire                                        mbds_finish_flag            ;
    wire                                        mbds_finish_flag_clr        ;

    reg                                         bram_prefetch               ;
    reg                                         bram_prefetch_type          ;
    reg                       [  31: 0]         bram_prefetch_addr  [2:0]   ;
    reg                                         i_wr_MUX_reg                ;
    wire                      [  11: 0]         o_rd_data_R                 ;
    wire                      [  11: 0]         o_rd_data_G                 ;
    wire                      [  11: 0]         o_rd_data_B                 ;
    
    reg                       [   9: 0]         BRAM_mb_cnt       [2:0]     ;
    reg                       [   9: 0]         BRAM_ds_cnt       [2:0]     ;
    reg                       [   9: 0]         g_pref_proc_vcnt            ;
    reg                       [   9: 0]         g_pref_matc_vcnt            ;

    wire                                        o_ena_dma_rd    [2:0]      ;
    wire                      [  31: 0]         o_addr_dma_rd     [2:0]     ;
    wire                      [  31: 0]         o_lenth_dma_rd  [2:0]      ;
    wire                                        i_finish_dma_rd   [2:0]     ;




    wire                      [   1: 0]         R_rd_type_d   [7:0]         ;
    wire                                        R_rd_ena_d    [7:0]         ;
    wire                      [  14: 0]         R_rd_addr     [7:0]         ;

    wire                      [   1: 0]         G_rd_type_d   [7:0]         ;
    wire                                        G_rd_ena_d    [7:0]         ;
    wire                      [  14: 0]         G_rd_addr     [7:0]         ;

    wire                      [   1: 0]         B_rd_type_d   [7:0]         ;
    wire                                        B_rd_ena_d    [7:0]         ;
    wire                      [  14: 0]         B_rd_addr     [7:0]         ;

    reg                                         start                       ;
    reg                       [  14: 0]         proc_block_addr             ;
    
    
    
    wire                                        rd_ena_wire_R     [7:0]     ;
    wire                                        rd_ena_wire_G     [7:0]     ;
    wire                                        rd_ena_wire_B     [7:0]     ;
    wire                      [  15: 0]         rd_addr_wire_R    [7:0]     ;
    wire                      [  15: 0]         rd_addr_wire_G    [7:0]     ;
    wire                      [  15: 0]         rd_addr_wire_B    [7:0]     ;
    wire                      [   1: 0]         rd_type_R         [7:0]     ;
    wire                      [   1: 0]         rd_type_G         [7:0]     ;
    wire                      [   1: 0]         rd_type_B         [7:0]     ;
    
    
    
    wire                      [  11: 0]         d_in_R            [7:0]     ;
    wire                      [  11: 0]         d_in_G            [7:0]     ;
    wire                      [  11: 0]         d_in_B            [7:0]     ;

    wire                      [   7: 0]         select_Temporal_R           ;
    wire                      [   7: 0]         select_Temporal_G           ;
    wire                      [   7: 0]         select_Temporal_B           ;


    wire                                        ME_TD_finish_flag           ;
    wire                                        metd_finish_clr             ;
    reg                       [H_DISP/4 -1: 0]  METD_info_R                 ;
    reg                       [H_DISP/4 -1: 0]  METD_info_G                 ;
    reg                       [H_DISP/4 -1: 0]  METD_info_B                 ;
    
    reg                       [$clog2(H_DISP/4) - 1: 0]  METD_cnt                     ;
    wire                                        o_rd_ena         [2:0][DATA_CHANNEL -1: 0];
    wire                      [  11: 0]         o_rd_address     [2:0][DATA_CHANNEL -1: 0];
    wire                      [   7: 0]         i_rd_data_process[2:0][DATA_CHANNEL -1: 0];
    wire                      [   7: 0]         i_rd_data_match  [2:0][DATA_CHANNEL -1: 0];
    wire                                        fsm_algo_start_pulse        ;
    reg                                         fsm_algo_start              ;
    wire                                        i_one_finish_clr            ;
    wire                                        o_one_MB_finish             ;
    wire                                        o_image_out_start           ;
    wire                                        o_line_transfer_finish_pulse;
    wire                                        o_frame_finish_pulse        ;
    wire                                        i_start_sys_pulse           ;
    reg                                         i_start_sys                 ;
    reg       [$clog2(V_DISP/4) - 1: 0]         algo_vcnt                   ;
    reg       [$clog2(H_DISP/4) - 1: 0]         algo_hcnt                   ;
    reg                                         prefetch                    ;
    wire                                        prefetch_pulse              ;
    wire                                        o_ena_dma_wr      [2:0]     ;
    wire                                        i_ddr_ready       [2:0]     ;
    wire                      [  31: 0]         o_lenth_dma_wr    [2:0]     ;
    wire                      [  31: 0]         o_addr_dma_wr     [2:0]     ;
    wire                      [  63: 0]         o_data_dma_wr     [2:0]     ;
    wire                                        o_d_val_dma_wr    [2:0]     ;
    wire                                        o_dma_ddr_finish  [2:0]     ;
    
    wire                                        o_ena_pre_rd      [2:0]     ;
    wire                      [  31: 0]         o_addr_pre_rd     [2:0]     ;
    wire                      [  31: 0]         o_lenth_pre_rd    [2:0]     ;
    wire                      [  63: 0]         i_data_pre_rd     [2:0]     ;
    wire                                        i_d_val_pre_rd    [2:0]     ;
    wire                                        i_finish_pre_rd   [2:0]     ;
    
    wire                      [  63: 0]         i_data            [2:0]     ;
    wire                                        i_d_val                     ;

    reg                       [   2: 0]         cur_st                      ;
    reg                                         frame_in_finish             ;
    reg                                         METD_start                  ;

    assign rst = ~rst_n;
    
    always @(posedge clk ) begin
        if (~rst_n) begin
            cur_st                              <=          IDLE            ;
            prefetch                            <=          1'b0            ;
        end
        else begin
            case (cur_st)
                IDLE         : begin
                    
                    if (i_fval_pulse) begin
                        cur_st                  <=          FIRST_FRAME     ;
                    end
                    else begin
                        cur_st                  <=          IDLE            ;
                    end
                end
                FIRST_FRAME  : begin 
                    if (wr_finish_clr) begin
                        cur_st                  <=          SECOND_FRAME    ;
                    end
                    else begin
                        cur_st                  <=          FIRST_FRAME     ;
                    end
                end
                SECOND_FRAME : begin
                    
                    if (wr_finish_clr) begin
                        cur_st                  <=          INIT_LOCAL_MAT  ;
                    end
                    else begin
                        cur_st                  <=          SECOND_FRAME    ;
                    end
                end
                INIT_LOCAL_MAT: begin
                    
                    if (mbds_finish_flag) begin
                        cur_st                  <=          INIT_LOCAL_PROC ;
                    end
                    else begin
                        cur_st                  <=          INIT_LOCAL_MAT  ;
                    end
                end
                INIT_LOCAL_PROC: begin
                    
                    
                    if (mbds_finish_flag) begin
                        cur_st                  <=          ME_TD           ;
                        prefetch                <=          1'b1            ;
                    end
                    else begin
                        cur_st                  <=          INIT_LOCAL_PROC ;
                    end
                end
                ME_TD        : begin
                    
                    
                    prefetch                    <=          1'b0            ;
                    if (ME_TD_finish_flag) begin
                        
                        if (METD_cnt == H_DISP/4 - 8) begin
                            cur_st              <=          ALGO            ;
                        end
                        else begin
                            cur_st              <=          ME_TD            ;
                        end
                    end
                    else begin
                        cur_st                  <=          ME_TD            ;
                    end
                end
                ALGO         : begin
                    
                    if (o_frame_finish_pulse) begin
                        
                        cur_st                  <=          FIRST_FRAME     ;
                    end
                    else if (o_line_transfer_finish_pulse) begin
                        
                        if (algo_vcnt == V_DISP /4 - 1) begin
                            cur_st              <=          IDLE            ;
                        end
                        else begin
                            cur_st              <=          ME_TD           ;
                        end
                    end
                    else begin
                        cur_st                  <=          ALGO            ;
                    end
                end
                default:    begin
                    cur_st                      <=          IDLE            ;
                end
            endcase
        end
    end

    reg                       [DATA_CHANNEL-1: 0]         fsm_metd_start    ;

    genvar i0;

    generate
        for (i0 = 0;i0 < 3;i0 = i0 + 1) begin
            always @(posedge clk ) begin
                if (~rst_n) begin
                    fsm_metd_start[i0]            <=          1'b0           ;
                end 
                else begin
                    if (cur_st == INIT_LOCAL_PROC && (M_rd_finish[i0])) begin
                        fsm_metd_start[i0]        <=          1'b1           ;
                    end 
                    else begin
                        fsm_metd_start[i0]        <=          1'b0           ;
                    end
                end
            end
        end
    endgenerate






U0_SinglePulse_SubSys u_U0_SinglePulse_SubSys(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .pos_dir0                                  (frame_in_finish            ),
    .pos_dir1                                  (i_fval                     ),
    .pos_dir2                                  (mbds_finish_flag           ),
    .pos_dir3                                  (ME_TD_finish_flag          ),
    .pos_dir4                                  (|fsm_metd_start            ),
    .pos_dir5                                  (o_one_MB_finish            ),
    .pos_dir6                                  (i_start_sys                ),
    .pos_dir7                                  (fsm_algo_start             ),
    .pos_dir8                                  (prefetch                   ),

    .pos_pulse0                                (wr_finish_clr              ),
    .pos_pulse1                                (i_fval_pulse               ),
    .pos_pulse2                                (mbds_finish_flag_clr       ),
    .pos_pulse3                                (metd_finish_clr            ),
    .pos_pulse4                                (fsm_metd_start_pulse       ),
    .pos_pulse5                                (i_one_finish_clr           ),
    .pos_pulse6                                (i_start_sys_pulse          ),
    .pos_pulse7                                (fsm_algo_start_pulse       ),
    .pos_pulse8                                (prefetch_pulse             ) 
);



    assign       wr_mux_sel                  = (cur_st == FIRST_FRAME) || (cur_st == SECOND_FRAME);
    assign       rd_mux_sel                  = (cur_st == ME_TD)            ;
    
    assign frame_proc_addr[0]  = R_PROC_ADDR;
    assign frame_proc_addr[1]  = G_PROC_ADDR;
    assign frame_proc_addr[2]  = B_PROC_ADDR;

    assign frame_match_addr[0] = R_MATCH_ADDR;
    assign frame_match_addr[1] = G_MATCH_ADDR;
    assign frame_match_addr[2] = B_MATCH_ADDR;

    assign data_flatten[0] = {i_data_R[7],i_data_R[6],i_data_R[5],i_data_R[4],i_data_R[3],i_data_R[2],i_data_R[1],i_data_R[0]};
    assign data_flatten[1] = {i_data_G[7],i_data_G[6],i_data_G[5],i_data_G[4],i_data_G[3],i_data_G[2],i_data_G[1],i_data_G[0]};
    assign data_flatten[2] = {i_data_B[7],i_data_B[6],i_data_B[5],i_data_B[4],i_data_B[3],i_data_B[2],i_data_B[1],i_data_B[0]};


    always @(posedge clk ) begin
        if (~rst_n) begin
            line_cnt                        <=          'b0                 ;
        end 
        else begin
            if (i_lval) begin
                if ((col_cnt == H_DISP - 8)) begin
                    if (line_cnt == V_DISP - 1) begin
                        line_cnt                <=          'b0             ;
                    end
                    else begin
                        line_cnt                <=          line_cnt + 1    ;
                    end
                end
                else begin
                    line_cnt                    <=          line_cnt        ;
                end
            end
            else begin
                line_cnt                        <=          line_cnt        ;
            end
        end
    end

    always @(posedge clk ) begin
        if (~rst_n) begin
            col_cnt                         <=          'b0                 ;
        end
        else begin
            if (i_lval) begin
                if (col_cnt == H_DISP - 8) begin
                    col_cnt                 <=          'b0                 ;
                end 
                else begin
                    col_cnt                 <=          col_cnt + DATA_CHANNEL;
                end 
            end 
            else begin
                col_cnt                     <=          col_cnt             ;
            end
        end
    end


    always @(posedge clk ) begin
        if (~rst_n) begin
            frame_in_finish                 <=          1'b0                ;
        end 
        else begin
            if (i_lval) begin
                if (col_cnt == H_DISP - 8 && line_cnt == V_DISP - 1 ) begin
                    frame_in_finish         <=          1'b1                ;
                end 
                else begin
                    frame_in_finish         <=          1'b0                ;
                end   
            end 
            else begin
                frame_in_finish             <=          1'b0                ;
            end
        end
    end




    genvar i1;

    generate
        for (i1 = 0; i1 < 3; i1 = i1 + 1) begin
            
            always @(posedge clk ) begin
                if (~rst_n) begin
                    frame_wr_addr[i1]                   <=          frame_match_addr[i1];
                end 
                else begin
                    if (wr_finish_clr) begin
                        if (frame_wr_addr[i1] == frame_match_addr[i1]) begin
                            frame_wr_addr[i1]           <=          frame_proc_addr[i1] ;
                        end 
                        else begin
                            frame_wr_addr[i1]           <=          frame_match_addr[i1];
                        end
                    end else begin
                        frame_wr_addr[i1]               <=          frame_wr_addr[i1]   ;
                    end    
                end
            end

            
            
            

            u_2_to_1_MUX#(
        .D_WIDTH                           (1                              ) 
            ) mux_2_1_start (
        .i_port0                           (i_fval_pulse                   ),
        .i_port1                           (o_ena_dma_wr[i1]               ),
        .sel                               (~wr_mux_sel                    ),
        .o_port_sel                        (M_wr_req[i1]                   ) 
            );

            u_2_to_1_MUX#(
            .D_WIDTH                                   (32                         ) 
            )
            mux_2_1_lenth(
            .i_port0                                   (IMAGE_DISP_SIZE            ),
            .i_port1                                   (o_lenth_dma_wr[i1]         ),
            .sel                                       (~wr_mux_sel                ),
            .o_port_sel                                (M_wr_len[i1]               ) 
            );

            u_2_to_1_MUX#(
            .D_WIDTH                                   (32                         ) 
            )
            mux_2_1_addr(
            .i_port0                                   (frame_wr_addr[i1]          ),
            .i_port1                                   (o_addr_dma_wr[i1]          ),
            .sel                                       (~wr_mux_sel                ),
            .o_port_sel                                (M_wr_addr[i1]              ) 
            );

            u_2_to_1_MUX#(
            .D_WIDTH                                   (64                         ) 
            )
            mux_2_1_data(
            .i_port0                                   (data_flatten[i1]           ),
            .i_port1                                   (o_data_dma_wr[i1]          ),
            .sel                                       (~wr_mux_sel                ),
            .o_port_sel                                (M_wr_din[i1]               ) 
            );

            u_2_to_1_MUX#(
            .D_WIDTH                                   (1                          ) 
            )
            mux_2_1_dval(
            .i_port0                                   (i_lval                     ),
            .i_port1                                   (o_d_val_dma_wr[i1]         ),
            .sel                                       (~wr_mux_sel                ),
            .o_port_sel                                (M_wr_dval[i1]              ) 
            );

            u_2_to_1_MUX#(
            .D_WIDTH                                   (1                          ) 
            )
            mux_2_1_finish(
            .i_port0                                   (wr_finish_clr              ),
            .i_port1                                   (o_dma_ddr_finish[i1]       ),
            .sel                                       (~wr_mux_sel                ),
            .o_port_sel                                (M_wr_finish[i1]            ) 
            );

            
            
            

            u_2_to_1_MUX#(
            .D_WIDTH                                   (1                          ) 
            )
            mux_2_1_start_rd(
            .i_port0                                   (o_ena_dma_rd[i1]           ),
            .i_port1                                   (o_ena_pre_rd[i1]           ),
            .sel                                       (rd_mux_sel                 ),
            .o_port_sel                                (M_rd_req[i1]               ) 
            );
            
            u_2_to_1_MUX#(
            .D_WIDTH                                   (32                         ) 
            )
            mux_2_1_lenth_rd(
            .i_port0                                   (o_lenth_dma_rd[i1]         ),
            .i_port1                                   (o_lenth_pre_rd[i1]         ),
            .sel                                       (rd_mux_sel                 ),
            .o_port_sel                                (M_rd_lenth[i1]             ) 
            );
            
            u_2_to_1_MUX#(
            .D_WIDTH                                   (32                         ) 
            )
            mux_2_1_addr_rd(
            .i_port0                                   (o_addr_dma_rd[i1]          ),
            .i_port1                                   (o_addr_pre_rd[i1]          ),
            .sel                                       (rd_mux_sel                 ),
            .o_port_sel                                (M_rd_addr[i1]              ) 
            );
            
            u_1_to_2_DEMUX#(
            .D_WIDTH                                   (64                         ) 
            )
            demux_2_1_data_rd(
            .o_port0                                   (DEMUX_rdout0[i1]           ),
            .o_port1                                   (i_data_pre_rd[i1]          ),
            .sel                                       (rd_mux_sel                 ),
            .i_port                                    (M_rd_dout[i1]              ) 
            );
            
            u_1_to_2_DEMUX#(
            .D_WIDTH                                   (1                          ) 
            )
            demux_2_1_dval_rd(
            .o_port0                                   (data_valid[i1]             ),
            .o_port1                                   (i_d_val_pre_rd[i1]         ),
            .sel                                       (rd_mux_sel                 ),
            .i_port                                    (M_rd_dval[i1]              ) 
            );
            
            u_1_to_2_DEMUX#(
            .D_WIDTH                                   (1                          ) 
            )
            demux_2_1_finish_rd(
            .o_port0                                   (i_finish_dma_rd[i1]        ),
            .o_port1                                   (i_finish_pre_rd[i1]        ),
            .sel                                       (rd_mux_sel                 ),
            .i_port                                    (M_rd_finish[i1]            ) 
            );

        end
    endgenerate



U1_Mul_Channel_DDR u_U1_Mul_Channel_DDR(
    .clk                                       (clk                        ),
    .ui_clk                                    (ui_clk                     ),
    .rst                                       (rst                        ),
    .ui_clk_sync_rst                           (ui_clk_sync_rst            ),

    .M_wr_req                                  (M_wr_req                   ),
    .M_wr_granted                              (M_wr_granted               ),
    .M_wr_busy                                 (M_wr_busy                  ),
    .M_wr_len                                  (M_wr_len                   ),
    .M_wr_addr                                 (M_wr_addr                  ),
    .M_wr_din                                  (M_wr_din                   ),
    .M_wr_dval                                 (M_wr_dval                  ),
    .M_wr_finish                               (M_wr_finish                ),

    .M_rd_req                                  (M_rd_req                   ),
    .M_rd_granted                              (M_rd_granted               ),
    .M_rd_busy                                 (M_rd_busy                  ),
    .M_rd_addr                                 (M_rd_addr                  ),
    .M_rd_lenth                                (M_rd_lenth                 ),
    .M_rd_dout                                 (M_rd_dout                  ),
    .M_rd_dval                                 (M_rd_dval                  ),
    .M_rd_finish                               (M_rd_finish                ),


    .M_AXI_AWID                                (M_AXI_AWID                 ),
    .M_AXI_AWADDR                              (M_AXI_AWADDR               ),
    .M_AXI_AWLEN                               (M_AXI_AWLEN                ),
    .M_AXI_AWSIZE                              (M_AXI_AWSIZE               ),
    .M_AXI_AWBURST                             (M_AXI_AWBURST              ),
    .M_AXI_AWLOCK                              (M_AXI_AWLOCK               ),
    .M_AXI_AWCACHE                             (M_AXI_AWCACHE              ),
    .M_AXI_AWPROT                              (M_AXI_AWPROT               ),
    .M_AXI_AWQOS                               (M_AXI_AWQOS                ),
    .M_AXI_AWUSER                              (M_AXI_AWUSER               ),
    .M_AXI_AWVALID                             (M_AXI_AWVALID              ),
    .M_AXI_AWREADY                             (M_AXI_AWREADY              ),
    
    .M_AXI_WDATA                               (M_AXI_WDATA                ),
    .M_AXI_WSTRB                               (M_AXI_WSTRB                ),
    .M_AXI_WLAST                               (M_AXI_WLAST                ),
    .M_AXI_WUSER                               (M_AXI_WUSER                ),
    .M_AXI_WVALID                              (M_AXI_WVALID               ),
    .M_AXI_WREADY                              (M_AXI_WREADY               ),
    
    .M_AXI_BID                                 (M_AXI_BID                  ),
    .M_AXI_BRESP                               (M_AXI_BRESP                ),
    .M_AXI_BUSER                               (M_AXI_BUSER                ),
    .M_AXI_BVALID                              (M_AXI_BVALID               ),
    .M_AXI_BREADY                              (M_AXI_BREADY               ),
    
    .M_AXI_ARID                                (M_AXI_ARID                 ),
    .M_AXI_ARADDR                              (M_AXI_ARADDR               ),
    .M_AXI_ARLEN                               (M_AXI_ARLEN                ),
    .M_AXI_ARSIZE                              (M_AXI_ARSIZE               ),
    .M_AXI_ARBURST                             (M_AXI_ARBURST              ),
    .M_AXI_ARLOCK                              (M_AXI_ARLOCK               ),
    .M_AXI_ARCACHE                             (M_AXI_ARCACHE              ),
    .M_AXI_ARPROT                              (M_AXI_ARPROT               ),
    .M_AXI_ARQOS                               (M_AXI_ARQOS                ),
    .M_AXI_ARUSER                              (M_AXI_ARUSER               ),
    .M_AXI_ARVALID                             (M_AXI_ARVALID              ),
    .M_AXI_ARREADY                             (M_AXI_ARREADY              ),
    
    .M_AXI_RID                                 (M_AXI_RID                  ),
    .M_AXI_RDATA                               (M_AXI_RDATA                ),
    .M_AXI_RRESP                               (M_AXI_RRESP                ),
    .M_AXI_RLAST                               (M_AXI_RLAST                ),
    .M_AXI_RUSER                               (M_AXI_RUSER                ),
    .M_AXI_RVALID                              (M_AXI_RVALID               ),
    .M_AXI_RREADY                              (M_AXI_RREADY               ) 

);



    assign data_in[0][7]                     = {DEMUX_rdout0[0][63:56]}     ;
    assign data_in[0][6]                     = {DEMUX_rdout0[0][55:48]}     ;
    assign data_in[0][5]                     = {DEMUX_rdout0[0][47:40]}     ;
    assign data_in[0][4]                     = {DEMUX_rdout0[0][39:32]}     ;
    assign data_in[0][3]                     = {DEMUX_rdout0[0][31:24]}     ;
    assign data_in[0][2]                     = {DEMUX_rdout0[0][23:16]}     ;
    assign data_in[0][1]                     = {DEMUX_rdout0[0][15: 8]}     ;
    assign data_in[0][0]                     = {DEMUX_rdout0[0][ 7: 0]}     ;

    assign data_in[1][7]                     = {DEMUX_rdout0[1][63:56]}     ;
    assign data_in[1][6]                     = {DEMUX_rdout0[1][55:48]}     ;
    assign data_in[1][5]                     = {DEMUX_rdout0[1][47:40]}     ;
    assign data_in[1][4]                     = {DEMUX_rdout0[1][39:32]}     ;
    assign data_in[1][3]                     = {DEMUX_rdout0[1][31:24]}     ;
    assign data_in[1][2]                     = {DEMUX_rdout0[1][23:16]}     ;
    assign data_in[1][1]                     = {DEMUX_rdout0[1][15: 8]}     ;
    assign data_in[1][0]                     = {DEMUX_rdout0[1][ 7: 0]}     ;

    assign data_in[2][7]                     = {DEMUX_rdout0[2][63:56]}     ;
    assign data_in[2][6]                     = {DEMUX_rdout0[2][55:48]}     ;
    assign data_in[2][5]                     = {DEMUX_rdout0[2][47:40]}     ;
    assign data_in[2][4]                     = {DEMUX_rdout0[2][39:32]}     ;
    assign data_in[2][3]                     = {DEMUX_rdout0[2][31:24]}     ;
    assign data_in[2][2]                     = {DEMUX_rdout0[2][23:16]}     ;
    assign data_in[2][1]                     = {DEMUX_rdout0[2][15: 8]}     ;
    assign data_in[2][0]                     = {DEMUX_rdout0[2][ 7: 0]}     ;



U2_MBDS_8CH_Subsys#(
    .CHANNEL_NUM                               (DATA_CHANNEL               ),
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ) 
)
u_U2_MBDS_8CH_Subsys(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),


    .R_ena                                     (bram_prefetch              ),
    .G_ena                                     (bram_prefetch              ),
    .B_ena                                     (bram_prefetch              ),

    .R_data_valid                              (data_valid[0]              ),
    .R_data_in                                 (data_in[0]                 ),
    .G_data_valid                              (data_valid[1]              ),
    .G_data_in                                 (data_in[1]                 ),
    .B_data_valid                              (data_valid[2]              ),
    .B_data_in                                 (data_in[2]                 ),




    .R_MB_dout                                 (MB_dout[0]                  ),
    .R_MB_ena                                  (MB_ena[0]                   ),
    .B_MB_dout                                 (MB_dout[2]                  ),
    .B_MB_ena                                  (MB_ena[2]                   ),
    .G_MB_dout                                 (MB_dout[1]                  ),
    .G_MB_ena                                  (MB_ena[1]                   ),



    .R_Sub_dout                                (Sub_dout[0]                 ),
    .R_Sub_ena                                 (Sub_ena[0]                  ),
    .G_Sub_dout                                (Sub_dout[1]                 ),
    .G_Sub_ena                                 (Sub_ena[1]                  ),
    .B_Sub_dout                                (Sub_dout[2]                 ),
    .B_Sub_ena                                 (Sub_ena[2]                  ),



    .finish_flag                               (mbds_finish_flag           ),
    .flag_clr                                  (mbds_finish_flag_clr       ) 
);



    always @(posedge clk ) begin
        if (~rst_n) begin
            bram_prefetch             <=        1'b0                        ;
            bram_prefetch_type        <=         'b0                        ;
            g_pref_matc_vcnt          <=         'b0                        ;
            g_pref_proc_vcnt          <=         'b0                        ;
        end
        else begin
            if (cur_st == SECOND_FRAME && wr_finish_clr) begin 
                bram_prefetch         <=        1'b1                        ;
                bram_prefetch_type    <=         'b0                        ;
                g_pref_matc_vcnt      <=        g_pref_matc_vcnt + 40       ;
            end 
            else if (cur_st == INIT_LOCAL_MAT && mbds_finish_flag) begin
                bram_prefetch         <=        1'b1                        ;
                bram_prefetch_type    <=         'b0                        ;
                g_pref_proc_vcnt      <=        g_pref_proc_vcnt + 40       ;
            end
            else if (cur_st == ME_TD && ME_TD_finish_flag) begin
                bram_prefetch         <=        1'b1                        ;
                bram_prefetch_type    <=         'b1                        ;
                if (i_wr_MUX_reg) begin
                    g_pref_proc_vcnt  <=        g_pref_proc_vcnt + 8        ;
                end
                else begin
                    g_pref_matc_vcnt  <=        g_pref_matc_vcnt + 8        ;
                end
            end
            else begin
                bram_prefetch         <=        1'b0                        ;
                bram_prefetch_type    <=         'b0                        ;
                g_pref_matc_vcnt      <=         'b0                        ;
                g_pref_proc_vcnt      <=         'b0                        ;
            end    
        end
    end


    always @(posedge clk ) begin
        if (~rst_n) begin
            i_wr_MUX_reg              <=          1'b0                      ;
        end
        else begin
            if (mbds_finish_flag) begin
                i_wr_MUX_reg          <=        ~i_wr_MUX_reg               ;
            end
            else begin
                i_wr_MUX_reg          <=         i_wr_MUX_reg               ;
            end
        end
    end

    genvar i2 ;

    generate
        for (i2 = 0; i2 < 3; i2 = i2 + 1) begin
            always @(posedge clk ) begin
                if (~rst_n) begin
                    bram_prefetch_addr[i2]        <=        'b0             ;
                end
                else begin
                    if (cur_st == SECOND_FRAME && wr_finish_clr) begin 
                        bram_prefetch_addr[i2]    <=        frame_match_addr[i2];
                    end 
                    else if (cur_st == INIT_LOCAL_MAT && mbds_finish_flag) begin
                        bram_prefetch_addr[i2]    <=        frame_proc_addr[i2] ;
                    end
                    else if (cur_st == ME_TD && ME_TD_finish_flag) begin
                        if (i_wr_MUX_reg) begin
                            bram_prefetch_addr[i2]<=        frame_proc_addr[i2] + g_pref_proc_vcnt * H_DISP * 3 ;
                        end
                        else begin
                            bram_prefetch_addr[i2]<=        frame_match_addr[i2]+ g_pref_matc_vcnt * H_DISP * 3 ;
                        end
                    end
                    else begin
                        bram_prefetch_addr[i2]    <=        'b0              ;
                    end    
                end
            end

            always @(posedge clk ) begin
                if (~rst_n) begin
                    BRAM_mb_cnt[i2]               <=          'b0                       ;  
                end 
                else begin
                    if (MB_ena[i2]) begin
                        if ((BRAM_mb_cnt[i2] == (18 * (H_DISP / 4)) - 1)) begin
                            BRAM_mb_cnt[i2]       <=          'b0                       ;
                        end
                        else begin
                            BRAM_mb_cnt[i2]       <=          BRAM_mb_cnt[i2] + 1       ;
                        end
                    end 
                    else begin
                        BRAM_mb_cnt[i2]           <=          BRAM_mb_cnt[i2]           ;
                    end    
                end
            end
        
            always @(posedge clk ) begin
                if (~rst_n) begin
                    BRAM_ds_cnt[i2]               <=          'b0                       ;  
                end 
                else begin
                    if (Sub_ena[i2]) begin
                        if ((BRAM_ds_cnt[i2] == (9 * (H_DISP/8)) - 1)) begin
                            BRAM_ds_cnt[i2]       <=          'b0                       ;
                        end
                        else begin
                            BRAM_ds_cnt[i2]       <=          BRAM_ds_cnt[i2] + 1       ;
                        end
                    end 
                    else begin
                        BRAM_ds_cnt[i2]           <=          BRAM_ds_cnt[i2]           ;
                    end    
                end
            end

        end
    endgenerate


U5_BRAM_Controller_Subsys u_U5_BRAM_Controller_Subsys(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),



    .prefetch                                  (bram_prefetch              ),
    .prefetch_type                             (bram_prefetch_type         ),
    .prefetch_addr                             (bram_prefetch_addr         ),



    .o_ena_dma_rd                              (o_ena_dma_rd               ),
    .o_addr_dma_rd                             (o_addr_dma_rd              ),
    .o_lenth_dma_rd                            (o_lenth_dma_rd             ),
    .i_finish_dma_rd                           (i_finish_dma_rd            ),




    .i_wr_MUX_reg_r                            (i_wr_MUX_reg               ),
    .i_wr_MUX_reg_g                            (i_wr_MUX_reg               ),
    .i_wr_MUX_reg_b                            (i_wr_MUX_reg               ),



    .i_wr_MB_ena_r                             (MB_ena[0]                  ),
    .i_wr_MB_addr_r                            (BRAM_mb_cnt[0]             ),
    .i_wr_MB_data_r                            (MB_dout[0]                 ),
    .i_wr_DS_ena_r                             (Sub_ena[0]                 ),
    .i_wr_DS_addr_r                            (BRAM_ds_cnt[0]             ),
    .i_wr_DS_data_r                            (Sub_dout[0]                ),



    .i_wr_MB_ena_g                             (MB_ena[1]                  ),
    .i_wr_MB_addr_g                            (BRAM_mb_cnt[1]             ),
    .i_wr_MB_data_g                            (MB_dout[1]                 ),
    .i_wr_DS_ena_g                             (Sub_ena[1]                 ),
    .i_wr_DS_addr_g                            (BRAM_ds_cnt[1]             ),
    .i_wr_DS_data_g                            (Sub_dout[1]                ),



    .i_wr_MB_ena_b                             (MB_ena[2]                  ),
    .i_wr_MB_addr_b                            (BRAM_mb_cnt[2]             ),
    .i_wr_MB_data_b                            (MB_dout[2]                 ),
    .i_wr_DS_ena_b                             (Sub_ena[2]                 ),
    .i_wr_DS_addr_b                            (BRAM_ds_cnt[2]             ),
    .i_wr_DS_data_b                            (Sub_dout[2]                ),



    .i_rd_MUX_reg                              (i_wr_MUX_reg               ),

    .i_rd_type_R                               (R_rd_type_d                ),
    .i_rd_type_G                               (G_rd_type_d                ),
    .i_rd_type_B                               (B_rd_type_d                ),
    .i_rd_ena_R                                (R_rd_ena_d                 ),
    .i_rd_ena_G                                (G_rd_ena_d                 ),
    .i_rd_ena_B                                (B_rd_ena_d                 ),
    .i_rd_addr_R                               (R_rd_addr                  ),
    .i_rd_addr_G                               (G_rd_addr                  ),
    .i_rd_addr_B                               (B_rd_addr                  ),

    .o_rd_data_R                               (d_in_R                     ),
    .o_rd_data_G                               (d_in_G                     ),
    .o_rd_data_B                               (d_in_B                     ) 
);



u_Addr_Map_Subsys#(
    .H_DISP                                    (H_DISP                    ),
    .V_DISP                                    (V_DISP                    ),
    .CHANNEL_NUM                               (DATA_CHANNEL               ) 
)
u_u_Addr_Map_Subsys(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .R_rd_ena                                  (rd_ena_wire_R              ),
    .R_rd_type                                 (rd_type_R                  ),
    .R_rd_site                                 (rd_addr_wire_R             ),
    
    .G_rd_ena                                  (rd_ena_wire_G              ),
    .G_rd_type                                 (rd_type_G                  ),
    .G_rd_site                                 (rd_addr_wire_G             ),
    
    .B_rd_ena                                  (rd_ena_wire_B              ),
    .B_rd_type                                 (rd_type_B                  ),
    .B_rd_site                                 (rd_addr_wire_B             ),

    .R_rd_type_d                               (R_rd_type_d                ),
    .R_rd_ena_d                                (R_rd_ena_d                 ),
    .R_rd_addr                                 (R_rd_addr                  ),

    .G_rd_type_d                               (G_rd_type_d                ),
    .G_rd_ena_d                                (G_rd_ena_d                 ),
    .G_rd_addr                                 (G_rd_addr                  ),

    .B_rd_type_d                               (B_rd_type_d                ),
    .B_rd_ena_d                                (B_rd_ena_d                 ),
    .B_rd_addr                                 (B_rd_addr                  ) 
);



U4_ME_TD_Subsys#(
    .H_DISP                                    (640                        ),
    .V_DISP                                    (480                        ),
    .CHANNEL_NUM                               (8                          ),
    .MACRO_BLOCK_THRESHOLD                     (0                          ) 
)
u_U4_ME_TD_Subsys(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .start                                     (METD_start | fsm_metd_start_pulse),
    .proc_block_addr                           (METD_cnt                   ),

    .rd_ena_wire_R                             (rd_ena_wire_R              ),
    .rd_ena_wire_G                             (rd_ena_wire_G              ),
    .rd_ena_wire_B                             (rd_ena_wire_B              ),
    .rd_addr_wire_R                            (rd_addr_wire_R             ),
    .rd_addr_wire_G                            (rd_addr_wire_G             ),
    .rd_addr_wire_B                            (rd_addr_wire_B             ),
    .rd_type_R                                 (rd_type_R                  ),
    .rd_type_G                                 (rd_type_G                  ),
    .rd_type_B                                 (rd_type_B                  ),

    .d_in_R                                    (d_in_R                     ),
    .d_in_G                                    (d_in_G                     ),
    .d_in_B                                    (d_in_B                     ),

    .select_Temporal_R                         (select_Temporal_R          ),
    .select_Temporal_G                         (select_Temporal_G          ),
    .select_Temporal_B                         (select_Temporal_B          ),

    .ME_TD_finish_flag                         (ME_TD_finish_flag          ),
    .finish_clr                                (metd_finish_clr            ) 
);



    always @(posedge clk ) begin
        if (~rst_n) begin
            METD_start        <=         'b0                                ;
        end 
        else begin
            if (ME_TD_finish_flag) begin
                if (METD_cnt == (H_DISP/4 - 8)) begin
                    METD_start<=         'b0                                ;
                end
                else begin
                    METD_start<=         'b1                                ;
                end
            end 
            else begin
                METD_start    <=         'b0                                ;
            end
        end
    end


    always @(posedge clk ) begin
        if (~rst_n) begin
            METD_cnt          <=        'b0                                 ;
        end 
        else begin
            if (ME_TD_finish_flag) begin
                if (METD_cnt == (H_DISP/4 - 8)) begin
                    METD_cnt  <=        'b0                                 ;
                end
                else begin
                    METD_cnt  <=        METD_cnt + 8                        ;
                end
            end 
            else begin
                METD_cnt      <=        METD_cnt                            ;    
            end
        end
    end



    always @(posedge clk ) 
    begin
        if (~rst_n) begin
            METD_info_R             <=         'b0                          ;
            METD_info_G             <=         'b0                          ;
            METD_info_B             <=         'b0                          ;
        end
        else begin
            if (o_one_MB_finish) begin
                METD_info_R         <=      {METD_info_R[H_DISP/4-2:0],1'b0};
                METD_info_G         <=      {METD_info_G[H_DISP/4-2:0],1'b0};
                METD_info_B         <=      {METD_info_B[H_DISP/4-2:0],1'b0};
            end
            else if (ME_TD_finish_flag) begin
                METD_info_R         <=      {METD_info_R[H_DISP/4-8:0],select_Temporal_R};
                METD_info_G         <=      {METD_info_G[H_DISP/4-8:0],select_Temporal_G};
                METD_info_B         <=      {METD_info_B[H_DISP/4-8:0],select_Temporal_B};
            end
            else begin
                METD_info_R         <=         METD_info_R                  ;
                METD_info_G         <=         METD_info_G                  ;
                METD_info_B         <=         METD_info_B                  ;
            end
        end
    end


U6_Algorithm_Subsys#(
    .DDR_BASE_ADDR                             (DDR_BASE_ADDR              ),
    .WAIT                                      (WAIT                       ),
    .HSYNC_PERIOD                              (0                          ),
    .VSYNC_PERIOD                              (0                          ),
    .H_BACK_PORCH                              (88                         ),
    .H_DISP                                    (H_DISP                     ),
    .H_FRONT_PORCH                             (88                         ),
    .V_BACK_PORCH                              (10                         ),
    .V_DISP                                    (V_DISP                     ),
    .V_FRONT_PORCH                             (10                         ),
    .CHANNEL_NUM                               (DATA_CHANNEL               ) 
)
u_U6_Algorithm_Subsys(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .i_temporal_weight                         (TEMPORAL_CALCULATE_PARAM   ),



    .i_start_sys                               (i_start_sys_pulse | fsm_algo_start_pulse),
    .i_macroblock_addr                         (algo_hcnt                  ),
    .i_select_tmp_R                            (METD_info_R[H_DISP/4 - 1]  ),
    .i_select_tmp_G                            (METD_info_G[H_DISP/4 - 1]  ),
    .i_select_tmp_B                            (METD_info_B[H_DISP/4 - 1]  ),



    .o_rd_ena                                  (o_rd_ena                   ),
    .o_rd_address                              (o_rd_address               ),
    .i_rd_data_process                         (i_rd_data_process          ),
    .i_rd_data_match                           (i_rd_data_match            ),



    .i_one_finish_clr                          (i_one_finish_clr           ),
    .o_one_MB_finish                           (o_one_MB_finish            ),

    .o_image_out_start                         (o_image_out_start          ),
    .o_line_transfer_finish_pulse              (o_line_transfer_finish_pulse),
    .o_frame_finish_pulse                      (o_frame_finish_pulse       ),



    .o_posted_data_R                           (o_data_R                   ),
    .o_posted_data_G                           (o_data_G                   ),
    .o_posted_data_B                           (o_data_B                   ),

    .o_d_val                                   (o_lval                     ),
    .o_Vsync                                   (o_fval                     ),
    .o_Hsync                                   (o_lval                     ) 
);


always @(posedge clk ) begin
    if (~rst_n) begin
        algo_vcnt           <=      'b0                                 ;
    end 
    else begin
        if (o_line_transfer_finish_pulse) begin
            if (algo_vcnt == V_DISP/4 - 1) begin
                algo_vcnt   <=      'b0                                 ;
            end 
            else begin
                algo_vcnt   <=      algo_vcnt + 1                       ;
            end
        end 
        else begin
            algo_vcnt       <=      algo_vcnt                           ;
        end
    end
end
    
always @(posedge clk ) begin
    if (~rst_n) begin
        algo_hcnt           <=      'b0                                 ;
    end 
    else begin
        if (o_one_MB_finish) begin
            if (algo_hcnt == H_DISP/4 - 8) begin
                algo_hcnt   <=      'b0                                 ;
            end 
            else begin
                algo_hcnt   <=      algo_hcnt + 8                       ;
            end
        end 
        else begin
            algo_hcnt       <=      algo_hcnt                           ;    
        end    
    end
end

always @(posedge clk ) begin
    if (~rst_n) begin
        i_start_sys         <=      'b0                                 ;
    end 
    else begin
        if (o_one_MB_finish) begin
            if (algo_hcnt == (H_DISP/4 - 8)) begin
                i_start_sys <=      1'b0                                ;    
            end
            else begin
                i_start_sys <=      1'b1                                ;
            end
        end
        else begin
            i_start_sys     <=      1'b0                                ;    
        end
    end
end


    genvar i7;

    generate
        for (i7 = 0; i7 < DATA_CHANNEL; i7 = i7 + 1)begin
            assign i_data[0][i7*8+8 -1:i7*8] =  o_data_R[i7]                ;
            assign i_data[1][i7*8+8 -1:i7*8] =  o_data_G[i7]                ;
            assign i_data[2][i7*8+8 -1:i7*8] =  o_data_B[i7]                ;
        end
    endgenerate

U7_DDR_DMA#(
    .V_DISP                                    (V_DISP                     ),
    .H_DISP                                    (H_DISP                     ),
    .MATCH_ADDRESS                             (0                          ),
    .PROC_ADDRESS                              (32'h8000_0000              ),
    .R_OFFSET                                  (32'h0000_0000              ),
    .G_OFFSET                                  (32'h0100_0000              ),
    .B_OFFSET                                  (32'h0200_0000              ),
    .CHANNEL_NUM                               (DATA_CHANNEL               )
)
u_U7_DDR_DMA(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    
    .line_finish                               (o_image_out_start          ),
    .frame_finish                              (o_frame_finish_pulse       ),
    .prefetch                                  (prefetch                   ),
    
    .o_ena_dma_wr                              (o_ena_dma_wr               ),
    .i_ddr_ready                               (i_ddr_ready                ),
    .o_lenth_dma_wr                            (o_lenth_dma_wr             ),
    .o_addr_dma_wr                             (o_addr_dma_wr              ),
    .o_data_dma_wr                             (o_data_dma_wr              ),
    .o_d_val_dma_wr                            (o_d_val_dma_wr             ),
    .o_dma_ddr_finish                          (o_dma_ddr_finish           ),

    .o_ena_dma_rd                              (o_ena_pre_rd               ),
    .o_addr_dma_rd                             (o_addr_pre_rd              ),
    .o_lenth_dma_rd                            (o_lenth_pre_rd             ),
    .i_data_dma_rd                             (i_data_pre_rd              ),
    .i_d_val_dma_rd                            (i_d_val_pre_rd             ),
    .i_finish_dma_rd                           (i_finish_pre_rd            ),

    .i_data                                    (i_data                     ),
    .i_d_val                                   (o_lval                     ),

    .i_proc_RAM_ena                            (o_rd_ena                   ),
    .i_proc_RAM_addr                           (o_rd_address               ),
    .o_proc_RAM_data                           (i_rd_data_process          ),
    .i_match_RAM_ena                           (o_rd_ena                   ),
    .i_match_RAM_addr                          (o_rd_address               ),
    .o_match_RAM_data                          (i_rd_data_match            ) 
);



endmodule






