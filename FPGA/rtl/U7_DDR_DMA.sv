`timescale 1ns / 1ps

//{ signal: [
//    { name: "clk               " , wave:"P..|.....|...|....||....|...|....." },
//    { name: "rst               " , wave:"lhl|.....|...|....||....|...|....." },
//    { name: "line_finish       " , wave:"l..|.hl..|...|....||hl..|...|....." },
//    { name: "i_data            " , wave:"x..|.....|.5.|.x..||....|.5.|.x..." ,data:["后处理数�?0","后处理数�?1"]},
//    { name: "i_d_val           " , wave:"l..|.....|.h.|.l..||....|.h.|.l..." },
//    { name: "frame_finish      " , wave:"l..|.....|...|....||....|...|...hl" },
//
//    { name: "o_ena_dma_wr      " , wave:"l..|...hl|...|....||..hl|...|....." },
//    { name: "i_ddr_ready       " , wave:"h..|....l|...|...h||...l|...|....h" },
//    { name: "o_lenth_dma_wr    " , wave:"x..|...3x|...|....||..3x|...|....." ,data:["len0","len1","len2"]},
//    { name: "o_addr_dma_wr     " , wave:"x..|...3x|...|....||..3x|...|....." ,data:["addr0","addr1","addr2"]},
//    { name: "o_data_dma_wr     " , wave:"x..|.....|.3.|.x..||....|.3.|.x..." ,data:["stdstream0","stdstream1","stdstream2"]},
//    { name: "o_d_val_dma_wr    " , wave:"l..|.....|.h.|.l..||....|.h.|.l..." },
//    { name: "o_dma_ddr_finish  " , wave:"l..|.....|...|..hl||....|...|...hl" },
//
//    { name: "clk               " , wave:"P..|....|....|....." },
//    { name: "rst               " , wave:"lhl|....|....|....." },
//    { name: "prefetch          " , wave:"l..|.hl.|....|......."},
//    { name: "o_ena_dma_rd      " , wave:"l..|..hl|....|......." },
//    { name: "o_addr_dma_rd     " , wave:"x..|..4x|....|......." ,data:["raddr0"]},
//    { name: "o_lenth_dma_rd    " , wave:"x..|..4x|....|......." ,data:["rlen0"]},
//    { name: "i_data_dma_rd     " , wave:"x..|....|.4..|.x....." ,data:["stdstream"]},
//    { name: "i_d_val_dma_rd    " , wave:"l..|....|.h..|.l....." },
//    { name: "i_finish_dma_rd   " , wave:"l..|....|....|.....hl" },
//
//  ],
//  head: {
//    text: 'DDR_DMA',
//    every: 1
//  },
//  config: { hscale: 1 }



module U7_DDR_DMA #(
    parameter                 V_DISP                      = 480                      ,
    parameter                 H_DISP                      = 480                      ,
    parameter                 MATCH_ADDRESS               = 0                        ,
    parameter                 PROC_ADDRESS                = 32'h8000_0000            ,
    parameter                 R_OFFSET                    = 32'h0100_0000            ,
    parameter                 G_OFFSET                    = 32'h0200_0000            ,
    parameter                 B_OFFSET                    = 32'h0300_0000            ,
    parameter                 CHANNEL_NUM                 = 8     
)(
    input                                       clk                                  ,//! 时钟
    input                                       rst                                  ,//! 复位

    input                                       line_finish                          ,//! 驱动模块�?始与DDR写交�?
    input                                       frame_finish                         ,//! 算法模块完成了一整帧处理并发送，不用再工作，清除部分计数�?
    input                                       prefetch                             ,//! 驱动模块�?始与DDR读交�?
    
    output                                      o_ena_dma_wr    [2:0]                ,//! 本地写请�?
    input                                       i_ddr_ready     [2:0]                ,//! DDR准备好接收写数据
    output                    [  31: 0]         o_lenth_dma_wr  [2:0]                ,//! 本地写长度：单位为打拍次�?
    output reg                [  31: 0]         o_addr_dma_wr   [2:0]                ,//! 本地写地�?
    output                    [  63: 0]         o_data_dma_wr   [2:0]                ,//! 本地写数�?
    output                                      o_d_val_dma_wr  [2:0]                ,//! 本地写数据有�?
    output                                      o_dma_ddr_finish[2:0]                ,//! 本地写完�?

    output                                      o_ena_dma_rd    [2:0]                ,//! 本地读请�?
    output reg                [  31: 0]         o_addr_dma_rd   [2:0]                ,//! 本地读地�?
    output                    [  31: 0]         o_lenth_dma_rd  [2:0]                ,//! 本地读长�?
    input                     [  63: 0]         i_data_dma_rd   [2:0]                ,//! 本地读数�?
    input                                       i_d_val_dma_rd  [2:0]                ,//! 本地读数据有�?
    input                                       i_finish_dma_rd [2:0]                ,//! 本地读完�?

    input                     [  63: 0]         i_data          [2:0]                ,//! 写请求后直接与写数据端口相连
    input                                       i_d_val                              ,//! 写请求后直接与写数据有效相连

    input                                       i_proc_RAM_ena  [2:0][CHANNEL_NUM -1: 0],//! 预取处理帧像素的R分量
    input                     [  11: 0]         i_proc_RAM_addr [2:0][CHANNEL_NUM -1: 0],//! 预取处理帧像素的R分量
    output                    [   7: 0]         o_proc_RAM_data [2:0][CHANNEL_NUM -1: 0],//! 预取处理帧像素的R分量

    input                                       i_match_RAM_ena [2:0][CHANNEL_NUM -1: 0],//! 预取参�?�帧像素的R分量
    input                     [  11: 0]         i_match_RAM_addr[2:0][CHANNEL_NUM -1: 0],//! 预取参�?�帧像素的R分量
    output                    [   7: 0]         o_match_RAM_data[2:0][CHANNEL_NUM -1: 0] //! 预取参�?�帧像素的R分量

);

    localparam                idle                        = 0     ;
    localparam                wait_ready                  = 1     ;
    localparam                transfer_data               = 2     ;
    localparam                transfer_finish             = 3     ;
    localparam                rd_idle                     = 0     ;
    localparam                rd_match                    = 1     ;
    localparam                rd_proc                     = 2     ;
    localparam                rd_finish                   = 3     ;

    reg                       [   2: 0]         state_r                     ;
    reg                       [  11: 0]         pixel_cnt                   ;
    wire                                        i_finish_dma_rd_sum         ;
    reg                       [   2: 0]         i_finish_dma_rd_tmp         ;
    reg                                         o_dma_ddr_finish_r [2:0]    ;
    reg                       [  31: 0]         offset         [2:0]        ;
    reg                                         o_ena_dma_rd_r [2:0]        ;
    reg                       [   1: 0]         r_state                     ;
    reg                       [  11: 0]         bram_address   [2:0]        ;
    wire                                        proc_bram_ena  [2:0]        ;
    wire                                        match_bram_ena [2:0]        ;

    wire                      [   7: 0]         proc_bram_data [2:0][CHANNEL_NUM-1:0];
    wire                      [   7: 0]         match_bram_data[2:0][CHANNEL_NUM-1:0];
    wire                      [  11: 0]         match_bram_addr[2:0][CHANNEL_NUM-1:0];
    wire                      [  11: 0]         proc_bram_addr [2:0][CHANNEL_NUM-1:0];

    wire                      [   7: 0]         inmux_data     [2:0][CHANNEL_NUM-1:0];

    genvar b;

    generate
        for (b = 0; b < CHANNEL_NUM; b =b + 1) begin
            assign        inmux_data[0][b] = i_data_dma_rd[0][7+b*8:b*8];
            assign        inmux_data[1][b] = i_data_dma_rd[1][7+b*8:b*8];
            assign        inmux_data[2][b] = i_data_dma_rd[2][7+b*8:b*8];
        end

    endgenerate


    assign        o_ena_dma_wr[0]    =          line_finish                 ;
    assign        o_ena_dma_wr[1]    =          line_finish                 ;
    assign        o_ena_dma_wr[2]    =          line_finish                 ;

    always @(posedge clk ) begin
        if (rst) begin
            state_r                 <=          idle                        ;
        end 
        else begin
            case (state_r)
                idle: begin
                    if (line_finish) begin
                        state_r     <=          wait_ready                  ;
                    end 
                    else begin
                        state_r     <=          idle                        ;
                    end
                end
                wait_ready: begin
                    if (i_ddr_ready[0]&i_ddr_ready[1]&i_ddr_ready[2]) begin
                        state_r     <=          transfer_data               ;
                    end 
                    else begin
                        state_r     <=          wait_ready                  ;
                    end
                end
                transfer_data: begin
                    if (pixel_cnt >= H_DISP * 4 - 8) begin
                        state_r     <=          transfer_finish             ;
                    end 
                    else begin
                        state_r     <=          transfer_data               ;
                    end
                end
                transfer_finish: begin
                    state_r         <=          idle                        ;
                end
                default: begin
                    state_r         <=          idle                        ;
                end
            endcase
        end
    end


    always @(posedge clk ) begin
        if (rst) begin
            pixel_cnt               <=          'b0                         ;
        end 
        else begin
            if (pixel_cnt >= H_DISP * 4 - 8) begin
                pixel_cnt           <=          'b0                         ;
            end 
            else if (i_d_val) begin
                pixel_cnt           <=          pixel_cnt + 8               ;
            end
            else begin
                pixel_cnt           <=          pixel_cnt                   ;
            end
        end
    end


    genvar i;

    generate
        for (i = 0; i < 3; i = i + 1) begin
            always @(posedge clk ) begin
                if (rst) begin
                    o_dma_ddr_finish_r[i]      <=          1'b0                        ;
                end 
                else begin
                    if (state_r == transfer_finish) begin
                        o_dma_ddr_finish_r[i]  <=          1'b1                        ;
                    end 
                    else begin
                        o_dma_ddr_finish_r[i]  <=          1'b0                        ;
                    end
                end
            end
        
            U0_SinglePulse u_U0_SinglePulse_wr_finish(
                .clk                                       (clk                        ),
                .rst                                       (rst                        ),
                .pos_dir                                   (o_dma_ddr_finish_r[i]      ),
                .pos_pulse                                 (o_dma_ddr_finish[i]        ) 
            );

            u_2_to_1_MUX #(
                .D_WIDTH                                   (1                          ) 
            )u_u_2_to_1_MUX_d_val(
                .i_port0                                   (1'b0                       ),
                .i_port1                                   (i_d_val                    ),
                .sel                                       ((state_r == transfer_data) ),
                .o_port_sel                                (o_d_val_dma_wr[i]          ) 
            );
            
            u_2_to_1_MUX  #(
                .D_WIDTH                                   (64                         ) 
            )u_u_2_to_1_MUX_data(
                .i_port0                                   (64'b0                      ),
                .i_port1                                   (i_data[i]                  ),
                .sel                                       ((state_r == transfer_data) ),
                .o_port_sel                                (o_data_dma_wr[i]           ) 
            );
        
            U0_SinglePulse u_U0_SinglePulse_rd_ena(
                .clk                                       (clk                        ),
                .rst                                       (rst                        ),
                .pos_dir                                   (o_ena_dma_rd_r[i]          ),
                .pos_pulse                                 (o_ena_dma_rd[i]            ) 
            );

            always @(posedge clk ) begin
                if (rst) begin
                    offset[i]                      <=                  'b0                ;
                end 
                else begin
                    if (frame_finish) begin
                        offset[i]                  <=                  'b0                ;
                    end
                    else if (r_state == rd_finish) begin
                        offset[i]                  <=                  offset[i] + H_DISP * 4;
                    end 
                    else begin
                        offset[i]                  <=                  offset[i]          ;    
                    end
                end
            end

            always @(posedge clk ) begin//两续两大行读�?
                if (rst) begin
                    o_ena_dma_rd_r[i]              <=                  1'b0               ;
                end 
                else begin
                    if (prefetch) begin
                        o_ena_dma_rd_r[i]          <=                  1'b1               ;
                    end 
                    else if ((r_state == rd_match) && i_finish_dma_rd_sum) begin
                        o_ena_dma_rd_r[i]          <=                  1'b1               ;
                    end
                    else begin
                        o_ena_dma_rd_r[i]          <=                  1'b0               ;
                    end
                end
            end

            always @(posedge clk ) 
            begin
                if (rst) begin
                    i_finish_dma_rd_tmp[i]         <=                  'b0                ; 
                end 
                else begin
                    if (i_finish_dma_rd_sum) begin
                        i_finish_dma_rd_tmp[i]     <=                  'b0                ;
                    end
                    else if (i_finish_dma_rd[i]) begin
                        i_finish_dma_rd_tmp[i]     <=                  'b1                ; 
                    end 
                    else begin
                        i_finish_dma_rd_tmp[i]     <=     i_finish_dma_rd_tmp[i]          ; 
                    end    
                end
            end

            always @(posedge clk ) begin
                if (rst) begin
                    bram_address[i]                <=                  'b0                ;
                end
                else begin
                    if (i_d_val_dma_rd[i]) begin
                        if (bram_address[i] == H_DISP * 4 - 8) begin
                            bram_address[i]        <=                  'b0                ;
                        end 
                        else begin
                            bram_address[i]        <=                  bram_address[i] + 8;    
                        end
                    end else begin
                        bram_address[i]            <=                  bram_address[i]    ;
                    end
                end
            end

        end
    endgenerate

    assign i_finish_dma_rd_sum     = (i_finish_dma_rd_tmp == 3'b111)        ;

    assign                          o_lenth_dma_wr[0]           = H_DISP * 4;
    assign                          o_lenth_dma_wr[1]           = H_DISP * 4;
    assign                          o_lenth_dma_wr[2]           = H_DISP * 4;


    always @(posedge clk ) begin
        if (rst) begin
            o_addr_dma_wr[0]        <= MATCH_ADDRESS + R_OFFSET             ;
            o_addr_dma_wr[1]        <= MATCH_ADDRESS + G_OFFSET             ;
            o_addr_dma_wr[2]        <= MATCH_ADDRESS + B_OFFSET             ;
        end
        else begin
            if (frame_finish) begin
                o_addr_dma_wr[0]    <= MATCH_ADDRESS + R_OFFSET             ;
            end
            else if (o_dma_ddr_finish_r[0]) begin
                o_addr_dma_wr[0]    <= o_addr_dma_wr[0] + (H_DISP * 4)      ;
            end
            else begin
                o_addr_dma_wr[0]    <= o_addr_dma_wr[0]                     ;
            end

            if (frame_finish) begin
                o_addr_dma_wr[1]    <= MATCH_ADDRESS + G_OFFSET             ;
            end
            else if (o_dma_ddr_finish_r[1]) begin
                o_addr_dma_wr[1]    <= o_addr_dma_wr[1] + (H_DISP * 4)      ;
            end
            else begin
                o_addr_dma_wr[1]    <= o_addr_dma_wr[1]                     ;
            end

            if (frame_finish) begin
                o_addr_dma_wr[2]    <= MATCH_ADDRESS + B_OFFSET             ;
            end
            else if (o_dma_ddr_finish_r[2]) begin
                o_addr_dma_wr[2]    <= o_addr_dma_wr[2] + (H_DISP * 4)      ;
            end
            else begin
                o_addr_dma_wr[2]    <= o_addr_dma_wr[2]                     ;
            end

        end
    end

    always @(posedge clk ) begin//两续两大行读�?
        if (rst) begin
            o_addr_dma_rd[0]        <= offset[0] + MATCH_ADDRESS + R_OFFSET ;
            o_addr_dma_rd[1]        <= offset[1] + MATCH_ADDRESS + G_OFFSET ;
            o_addr_dma_rd[2]        <= offset[2] + MATCH_ADDRESS + B_OFFSET ;
        end
        else begin
            if (prefetch) begin
                o_addr_dma_rd[0]    <= offset[0] + MATCH_ADDRESS + R_OFFSET ;
                o_addr_dma_rd[1]    <= offset[1] + MATCH_ADDRESS + G_OFFSET ;
                o_addr_dma_rd[2]    <= offset[2] + MATCH_ADDRESS + B_OFFSET ;
            end
            else if ((r_state == rd_match) && i_finish_dma_rd_sum) begin
                o_addr_dma_rd[0]    <= offset[0] + PROC_ADDRESS  + R_OFFSET ;
                o_addr_dma_rd[1]    <= offset[1] + PROC_ADDRESS  + G_OFFSET ;
                o_addr_dma_rd[2]    <= offset[2] + PROC_ADDRESS  + B_OFFSET ;
            end
            else begin
                o_addr_dma_rd[0]    <= offset[0] + MATCH_ADDRESS + R_OFFSET ;
                o_addr_dma_rd[1]    <= offset[1] + MATCH_ADDRESS + G_OFFSET ;
                o_addr_dma_rd[2]    <= offset[2] + MATCH_ADDRESS + B_OFFSET ;
            end
        end
    end

    assign                          o_lenth_dma_rd[0]           = H_DISP * 4;
    assign                          o_lenth_dma_rd[1]           = H_DISP * 4;
    assign                          o_lenth_dma_rd[2]           = H_DISP * 4;

    always @(posedge clk ) begin
        if (rst) begin
            r_state                     <=                  rd_idle         ;
        end
        else begin
            case (r_state)
                rd_idle: begin
                    if (prefetch) begin
                        r_state         <=                  rd_match        ;
                    end
                    else begin
                        r_state         <=                  rd_idle         ;
                    end
                end
                rd_match: begin
                    if (i_finish_dma_rd_sum) begin
                        r_state         <=                  rd_proc         ;
                    end
                    else begin
                        r_state         <=                  rd_match        ;
                    end
                end
                rd_proc: begin
                    if (i_finish_dma_rd_sum) begin
                        r_state         <=                  rd_finish       ;
                    end
                    else begin
                        r_state         <=                  rd_proc         ;
                    end
                end
                rd_finish: begin
                        r_state         <=                  rd_idle         ;

                end
                default: begin
                    r_state             <=                  rd_idle         ;
                end
            endcase 
        end
    end

genvar a;
    generate

        genvar c;

        for (a = 0; a < 3; a = a + 1) begin

            for (c = 0; c < CHANNEL_NUM; c = c + 1) begin
                u_1_to_2_DEMUX #(
                    .D_WIDTH                                   (8                      ) 
                )u_u_1_to_2_DEMUX_rd_data(
                    .o_port0                                   (match_bram_data[a][c]  ),
                    .o_port1                                   (proc_bram_data [a][c]  ),
                    .sel                                       ((r_state == rd_proc)   ),
                    .i_port                                    (inmux_data[a][c]       ) 
                );
                
                u_1_to_2_DEMUX #(
                    .D_WIDTH                                   (12                     ) 
                )u_u_1_to_2_DEMUX_rd_addr(
                    .o_port0                                   (match_bram_addr[a][c]  ),
                    .o_port1                                   (proc_bram_addr [a][c]  ),
                    .sel                                       ((r_state == rd_proc)   ),
                    .i_port                                    (bram_address[a] + c    ) 
                );
            end

            u_1_to_2_DEMUX u_u_1_to_2_DEMUX_rd_ena(
                .o_port0                                   (match_bram_ena[a]          ),
                .o_port1                                   (proc_bram_ena [a]          ),
                .sel                                       ((r_state == rd_proc)       ),
                .i_port                                    (i_d_val_dma_rd[a]          ) 
            );
            
            U7_0_8_8_BRAM#(
                .ADDR_WIDTH                                (12                         ),
                .DATA_WIDTH                                (8                          ),
                .DEPTH                                     (H_DISP * 4                 ),
                .CH                                        (8                          ) 
            )u_U7_0_8_8_BRAM_proc(
                .clk                                       (clk                        ),
                .rst                                       (rst                        ),
                .we                                        ({8{proc_bram_ena[a]}}      ),
                .wr_addr                                   (proc_bram_addr[a]          ),
                .wr_data                                   (proc_bram_data[a]          ),

                .re                                        (i_proc_RAM_ena[a]          ),
                .rd_addr                                   (i_proc_RAM_addr[a]         ),
                .rd_data                                   (o_proc_RAM_data[a]         ) 
            );
        
            U7_0_8_8_BRAM#(
                .ADDR_WIDTH                                (12                         ),
                .DATA_WIDTH                                (8                          ),
                .DEPTH                                     (H_DISP * 4                 ),
                .CH                                        (8                          ) 
            )u_U7_0_8_8_BRAM_match(
                .clk                                       (clk                        ),
                .rst                                       (rst                        ),
                .we                                        ({8{match_bram_ena[a]}}     ),
                .wr_addr                                   (match_bram_addr[a]         ),
                .wr_data                                   (match_bram_data[a]         ),

                .re                                        (i_match_RAM_ena[a]         ),
                .rd_addr                                   (i_match_RAM_addr[a]        ),
                .rd_data                                   (o_match_RAM_data[a]        ) 
            );
        end
    endgenerate

endmodule
