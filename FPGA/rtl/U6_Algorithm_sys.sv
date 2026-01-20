`timescale 1ns / 1ps 

//{ signal: [
//    { name: "clk                         " , wave:"P...|...|....|....|...|....|....||......|.....|....|||......|.....|......" },
//    { name: "rst                         " , wave:"l.hl|...|....|....|...|....|....||......|.....|....|||......|.....|......" },
//    { name: "i_start_sys                 " , wave:"l...|.hl|....|....|.hl|....|....||......|.....|....|||......|.....|......" },
//    { name: "i_temporal_weight           " , wave:"x...|.3x|....|....|.3x|....|....||......|.....|....|||......|.....|......" ,data:["weight0","weight1"]},
//    { name: "i_select_tmp                " , wave:"x...|.3x|....|....|.3x|....|....||......|.....|....|||......|.....|......" ,data:["sel0","sel1"]},
//    { name: "i_macroblock_addr           " , wave:"x...|.3x|....|....|.3x|....|....||......|.....|....|||......|.....|......" ,data:["addr0","addr1"]},
//    { name: "o_rd_ena                    " , wave:"l...|...|.h..|l...|...|.h..|l...||......|.....|....|||......|.....|......" },
//    { name: "o_rd_address                " , wave:"x...|...|.456|x...|...|.456|x...||......|.....|....|||......|.....|......" ,data:["r_addr0","r_addr1","r_addr2","r_addr3"]},
//    { name: "i_rd_data_process           " , wave:"x...|...|..45|x...|...|..45|x...||......|.....|....|||......|.....|......" ,data:["din0","din1","din2","din3"]},
//    { name: "i_rd_data_match             " , wave:"x...|...|..45|x...|...|..45|x...||......|.....|....|||......|.....|......" ,data:["din0","din1","din2","din3"]},
//    { name: "o_one_block_process_finish  " , wave:"l...|...|....|.hl.|...|....|.hl.||......|.....|....|||......|.....|......" },
//    { name: "i_one_finish_clr            " , wave:"l...|...|....|..hl|...|....|..hl||......|.....|....|||......|.....|......" },
//    { name: "o_line_finish_pulse         " , wave:"l...|...|....|....|...|....|....||.hl...|.....|....|||.hl...|.....|......" },
//    { name: "i_image_out_start           " , wave:"l...|...|....|....|...|....|....||....hl|.....|....|||....hl|.....|......" },
//    { name: "o_line_transfer_finish_pulse" , wave:"l...|...|....|....|...|....|....||......|.....|.hl.|||......|.....|.hl..." },
//    { name: "o_frame_finish_pulse        " , wave:"l...|...|....|....|...|....|....||......|.....|....|||......|.....|....hl" },
//    { name: "o_posted_data               " , wave:"x...|...|....|....|...|....|....||......|.5..x|....|||......|.5..x|......" ,data:["VGA时序数据","VGA时序数据"]},
//    { name: "o_d_val                     " , wave:"x...|...|....|....|...|....|....||......|.5..x|....|||......|.5..x|......" ,data:["数据有效信号","数据有效信号"]},
//    { name: "o_Vsync                     " , wave:"x...|...|....|....|...|....|....||......|.5..x|....|||......|.5..x|......" ,data:["VGA场同步","VGA场同步"]},
//    { name: "o_Hsync                     " , wave:"x...|...|....|....|...|....|....||......|.5..x|....|||......|.5..x|......" ,data:["VGA行同步","VGA行同步"]}
//  ],
//  head: {
//    text: 'MacroBlock_SubSampling',
//    every: 1
//  },
//  config: { hscale: 1 }
//}


module U6_Algorithm_sys #(
    parameter                 DDR_BASE_ADDR               = 0     ,
    parameter                 WAIT                        = 0     ,
    parameter                 HSYNC_PERIOD                = 128   ,
    parameter                 VSYNC_PERIOD                = 2     ,
    parameter                 H_BACK_PORCH                = 10    ,
    parameter                 H_DISP                      = 480   ,
    parameter                 H_FRONT_PORCH               = 10    ,
    parameter                 V_BACK_PORCH                = 10    ,
    parameter                 V_DISP                      = 480   ,
    parameter                 V_FRONT_PORCH               = 10    ,
    parameter                 CHANNEL_NUM                 = 8     

)(
    input                                       clk                         ,//! 时钟  
    input                                       rst                         ,//! 复位

    input                     [   7: 0]         i_temporal_weight           ,//! 时域平滑滤波权重参数
    
    input                                       i_start_sys                 ,//! 系统开始：处理一个宏块的像素
    input                                       i_select_tmp                ,//! 此宏块使用时域/空域滤波处理
    input                     [  13: 0]         i_macroblock_addr           ,//! 宏块在一行里的地址，用于4行像素寻址

    output                                      o_rd_ena         [CHANNEL_NUM -1: 0],//! 读取像素使能
    output                    [  11: 0]         o_rd_address     [CHANNEL_NUM -1: 0],//! 读取像素地址

    input                     [   7: 0]         i_rd_data_process[CHANNEL_NUM -1: 0],//! 读取Prefetch处理BRAM像素
    input                     [   7: 0]         i_rd_data_match  [CHANNEL_NUM -1: 0],//! 读取Prefetch参考BRAM像素

    output wire                                 o_one_block_process_finish  ,//! 已经完成了单个宏块处理
    input                                       i_one_finish_clr            ,//! 清除系统状态
    output wire                                 o_line_finish_pulse         ,//! 处理完了一行宏块但是没有发送
    input                                       i_image_out_start           ,//! 开始发送4行后处理像素
    output wire                                 o_line_transfer_finish_pulse,//! 已经完全发送了4行处理后像素
    output wire                                 o_frame_finish_pulse        ,//! 已经处理并发送完了一整帧的数据

    output wire               [   7: 0]         o_posted_data    [CHANNEL_NUM -1: 0],//! 以VGA格式输出后处理数据
    output reg                                  o_d_val                     ,//! 数据输出使能
    output reg                                  o_Vsync                     ,//! 场同步信号
    output reg                                  o_Hsync                      //! 行同步信号
);


    localparam                H_SUM_PERIOD                =  H_BACK_PORCH + H_DISP + H_FRONT_PORCH;
    localparam                V_SUM_PERIOD                =  V_BACK_PORCH + V_DISP + V_FRONT_PORCH;

    
    reg                       [   3: 0]         local_state                 ;
    reg                       [   1: 0]         BRAM_line_cnt               ;
    reg                                         frame_finish                ;
    reg                                         cnt_ena                     ;
    reg                       [   9: 0]         h_cnt                       ;
    reg                       [   9: 0]         v_cnt                       ;

    wire                                        Bram_rd_ena                 ;
        //���������Ƿ����һ������
    reg                       [   7: 0]         block_cnt                   ;
    reg                                         line_finish                 ;
    reg                                         o_line_transfer_finish      ;

    wire                      [   7: 0]         d_out_Sp              [CHANNEL_NUM -1: 0];
    wire                      [   7: 0]         d_out_Tmp             [CHANNEL_NUM -1: 0];
    wire                                        d_out_val_Sp          [CHANNEL_NUM -1: 0];
    wire                                        d_out_val_Tmp         [CHANNEL_NUM -1: 0];
    wire                                        d_out_val             [CHANNEL_NUM -1: 0];
    wire                      [  12: 0]         d_out_addr_Sp         [CHANNEL_NUM -1: 0];
    wire                      [  12: 0]         d_out_addr_Tmp        [CHANNEL_NUM -1: 0];
    wire                      [  12: 0]         d_out_addr            [CHANNEL_NUM -1: 0];
    wire                      [   7: 0]         d_out                 [CHANNEL_NUM -1: 0];
    
    wire                      [   7: 0]         i_Sp_proc_data        [CHANNEL_NUM -1: 0];
    wire                      [   7: 0]         i_Tmp_proc_data       [CHANNEL_NUM -1: 0];
    wire                      [   7: 0]         i_Tmp_match_data      [CHANNEL_NUM -1: 0];
    wire                      [  11: 0]         o_Sp_rd_address       [CHANNEL_NUM -1: 0];
    wire                      [  13: 0]         o_Tmp_rd_address      [CHANNEL_NUM -1: 0];
    
    wire                                        Sp_block_process_finish     ;
    wire                                        Tmp_block_process_finish    ;
    wire                                        Sp_finish_clr               ;
    wire                                        Tmp_finish_clr              ;

    wire                                        i_w_Sp_start_pulse          ;
    wire                                        i_w_Tmp_start_pulse         ;

    wire                      [  13: 0]         i_w_Sp_macroblock_num       ;
    wire                      [  13: 0]         i_w_Tmp_macroblock_num      ;
    wire                                        o_Sp_rd_ena                 ;
    wire                                        o_Tmp_rd_ena                ;


    u_1_to_2_DEMUX #(
    .D_WIDTH                                   (14                         ) 
    )u_u_1_to_2_DEMUX_i_address(
    .o_port0                                   (i_w_Sp_macroblock_num      ),
    .o_port1                                   (i_w_Tmp_macroblock_num     ),
    .sel                                       (i_select_tmp               ),
    .i_port                                    (i_macroblock_addr          ) 
    );

    u_1_to_2_DEMUX #(
    .D_WIDTH                                   (1                          ) 
    )u_u_1_to_2_DEMUX_i_start_ena(
    .o_port0                                   (i_w_Sp_start_pulse         ),
    .o_port1                                   (i_w_Tmp_start_pulse        ),
    .sel                                       (i_select_tmp               ),
    .i_port                                    (i_start_sys                ) 
    );


    genvar a;

    generate
        for (a = 0; a < CHANNEL_NUM; a = a + 1) begin

            u_2_to_1_MUX  #(
                .D_WIDTH                                   (1                          ) 
            )u_u_2_to_1_MUX_o_rd_ena0(
                .i_port0                                   (o_Sp_rd_ena                ),
                .i_port1                                   (o_Tmp_rd_ena               ),
                .sel                                       (i_select_tmp               ),
                .o_port_sel                                (o_rd_ena[a]                ) 
            );
            
            u_2_to_1_MUX  #(
                .D_WIDTH                                   (12                         ) 
            )u_u_2_to_1_MUX_o_rd_address(
                .i_port0                                   (o_Sp_rd_address[a]         ),
                .i_port1                                   (o_Tmp_rd_address[a][11:0]  ),
                .sel                                       (i_select_tmp               ),
                .o_port_sel                                (o_rd_address[a]            ) 
            );
            
            u_1_to_2_DEMUX #(
                .D_WIDTH                                   (8                          ) 
            )u_u_1_to_2_DEMUX_i_proc_data(
                .o_port0                                   (i_Sp_proc_data[a]          ),
                .o_port1                                   (i_Tmp_proc_data[a]         ),
                .sel                                       (i_select_tmp               ),
                .i_port                                    (i_rd_data_process[a]       ) 
            );

        end
    endgenerate


    U6_0_Spatial_algorithm #(
        .V_DISP                                    (V_DISP                     ),
        .H_DISP                                    (H_DISP                     ) 
    )u_U6_0_Spatial_algorithm (
        .clk                                       (clk                        ),
        .rst                                       (rst                        ),
    
        .i_ena_single_pulse                        (i_w_Sp_start_pulse         ),
        .macroblock_num                            (i_w_Sp_macroblock_num      ),// �����ĵڼ������
        
        .rd_ena                                    (o_Sp_rd_ena                ),
        .generated_rd_addr                         (o_Sp_rd_address            ),
        
        .d_in_proc                                 (i_Sp_proc_data             ),
    
        .d_out                                     (d_out_Sp                   ),
        .d_out_vld                                 (d_out_val_Sp               ),
        .d_out_addr                                (d_out_addr_Sp              ),
    
        .algo_finish_flag                          (Sp_block_process_finish    ),
        .finish_clr                                (Sp_finish_clr              ) 
    );
    

    U6_1_Temporal_algorithm #(
        .V_DISP                                    (V_DISP                     ),
        .H_DISP                                    (H_DISP                     ) 
    )u_U6_1_Temporal_algorithm(
        .clk                                       (clk                        ),
        .rst                                       (rst                        ),
    
        .tmp_weight                                (i_temporal_weight          ),
    
        .ena                                       (i_w_Tmp_start_pulse        ),
        .macroblock_num                            (i_w_Tmp_macroblock_num     ),
    
        .rd_ena                                    (o_Tmp_rd_ena               ),
        .generated_rd_addr                         (o_Tmp_rd_address           ),
    
        .d_in_proc                                 (i_Tmp_proc_data            ),
        .d_in_match                                (i_Tmp_match_data           ),
    
        .d_out                                     (d_out_Tmp                  ),
        .d_out_vld                                 (d_out_val_Tmp              ),
        .d_out_addr                                (d_out_addr_Tmp             ),
    
        .algo_finish_flag                          (Tmp_block_process_finish   ),
        .finish_clr                                (Tmp_finish_clr             ) 
    );


    genvar b;

    generate
        for (b = 0; b < CHANNEL_NUM; b = b + 1) begin

            u_2_to_1_MUX  #(
                .D_WIDTH                                   (8                          ) 
            )u_u_2_to_1_MUX_o_d_out(
                .i_port0                                   (d_out_Sp[b]                ),
                .i_port1                                   (d_out_Tmp[b]               ),
                .sel                                       (i_select_tmp               ),
                .o_port_sel                                (d_out[b]                   ) 
            );
            
            u_2_to_1_MUX  #(
                .D_WIDTH                                   (13                         ) 
            )u_u_2_to_1_MUX_o_rd_ena(
                .i_port0                                   (d_out_addr_Sp[b]           ),
                .i_port1                                   (d_out_addr_Tmp[b]          ),
                .sel                                       (i_select_tmp               ),
                .o_port_sel                                (d_out_addr[b]              ) 
            );
            
            u_2_to_1_MUX  #(
                .D_WIDTH                                   (1                          ) 
            )u_u_2_to_1_MUX_o_d_val(
                .i_port0                                   (d_out_val_Sp[b]            ),
                .i_port1                                   (d_out_val_Tmp[b]           ),
                .sel                                       (i_select_tmp               ),
                .o_port_sel                                (d_out_val[b]               ) 
            );

        end
    endgenerate


    u_2_to_1_MUX  #(
        .D_WIDTH                                   (1                          ) 
    )u_u_2_to_1_MUX_o_finish_flag(
        .i_port0                                   (Sp_block_process_finish    ),
        .i_port1                                   (Tmp_block_process_finish   ),
        .sel                                       (i_select_tmp               ),
        .o_port_sel                                (o_one_block_process_finish ) 
    );

    u_1_to_2_DEMUX #(
        .D_WIDTH                                   (1                          ) 
    )u_u_1_to_2_DEMUX_i_flag_clr(
        .o_port0                                   (Sp_finish_clr              ),
        .o_port1                                   (Tmp_finish_clr             ),
        .sel                                       (i_select_tmp               ),
        .i_port                                    (i_one_finish_clr           ) 
    );


    wire                                       re         [CHANNEL_NUM-1:0]  ;
    wire                      [ 12: 0]         rd_addr    [CHANNEL_NUM-1:0]  ;

    genvar g1;

    generate
        for (g1 = 0; g1 < CHANNEL_NUM; g1 = g1 + 1) begin
            assign re[g1]      = Bram_rd_ena;
            assign rd_addr[g1] = g1 + h_cnt + (H_DISP * BRAM_line_cnt);
        end
    endgenerate

U6_0_8_8_BRAM#(
    .ADDR_WIDTH                                (13                         ),
    .DATA_WIDTH                                (8                          ),
    .DEPTH                                     (H_DISP * 4                 ),
    .CHANNEL                                   (8                          ) 
)
 u_U6_0_8_8_BRAM(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .we                                        (d_out_val                  ),
    .wr_addr                                   (d_out_addr                 ),
    .wr_data                                   (d_out                      ),
    .re                                        (re                         ),
    .rd_addr                                   (rd_addr                    ),
    .rd_data                                   (o_posted_data              ) 
);



    always @(posedge clk ) begin
        if (rst) begin
            o_d_val                         <=      1'b0                    ;
        end 
        else begin
            o_d_val                         <=      Bram_rd_ena             ;
        end 
    end

    always @(posedge clk ) begin
        if (rst) begin
            block_cnt                       <=      'b0                     ;
            line_finish                     <=      'b0                     ;
        end
        else begin
            if (o_one_block_process_finish) begin
                if (block_cnt >= (H_DISP / 4) - 1) begin
                    block_cnt               <=      'b0                     ;
                    line_finish             <=      1'b1                    ;
                end
                else begin
                    block_cnt               <=      block_cnt + 1           ;
                    line_finish             <=      1'b0                    ;
                end
            end
            else begin
                block_cnt                   <=      block_cnt               ;
                line_finish                 <=      1'b0                    ;
            end
        end
    end

    U0_SinglePulse Line_finish_pulse_generate(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .pos_dir                                   (line_finish                ),
    .pos_pulse                                 (o_line_finish_pulse        ) 
    );


    localparam                idle                        = 0     ;
    localparam                v_blank                     = 1     ;
    localparam                wait_for_data               = 2     ;
    localparam                roi_h_blank                 = 3     ;
    localparam                roi_h_data                  = 4     ;
    localparam                roi_h_back_blank            = 5     ;
    localparam                v_back_blank                = 6     ;


    reg data_wait;

    always @(posedge clk ) 
    begin
        if (rst) begin
            data_wait                   <= 1'b0             ;
        end 
        else begin
            if (o_line_transfer_finish_pulse) begin
                data_wait               <= 1'b0             ;
            end
            else if (i_image_out_start) begin
                data_wait               <= 1'b1             ;
            end 
            else begin
                data_wait               <= data_wait        ;
            end
        end
    end



    always @(posedge clk ) begin
        if (rst) begin
            local_state                 <= idle             ;
            cnt_ena                     <= 1'b0             ;
        end 
        else begin
            case (local_state)
            idle       : begin
                if (i_start_sys) begin
                    local_state         <= v_blank          ;
                    cnt_ena             <= 1'b1             ;
                end 
                else begin
                    local_state         <= idle             ;
                end
            end
            v_blank    : begin
                if (h_cnt == H_SUM_PERIOD - 8) begin
                    if (v_cnt == V_FRONT_PORCH - 1) begin
                        local_state     <= wait_for_data    ;
                        cnt_ena         <= 1'b0             ;
                    end 
                    else begin
                        local_state     <= v_blank          ;
                    end
                end 
                else begin
                    local_state         <= v_blank          ;
                end
            end
            wait_for_data : begin
                if (data_wait) begin
                    local_state         <= roi_h_blank      ;    
                    cnt_ena             <= 1'b1             ;
                end 
                else begin
                    local_state         <= wait_for_data    ;
                end
            end
            roi_h_blank: begin
                if (h_cnt == H_FRONT_PORCH - 8) begin
                    local_state         <= roi_h_data       ;    
                end 
                else begin
                    local_state         <= roi_h_blank      ;
                end
            end
            roi_h_data : begin
                if (h_cnt == H_FRONT_PORCH + H_DISP - 8) begin
                    local_state         <= roi_h_back_blank ;
                end else begin
                    local_state         <= roi_h_data       ;
                end
            end
            roi_h_back_blank: begin
                if (h_cnt == H_SUM_PERIOD - 8) begin
                    if (v_cnt >= V_FRONT_PORCH + V_DISP - 1) begin
                        local_state     <= v_back_blank     ;
                    end 
                    else begin
                        local_state     <= wait_for_data    ;
                    end
                end else begin
                    local_state         <= roi_h_back_blank ;
                end
            end
            v_back_blank    : begin
                if (h_cnt == H_SUM_PERIOD - 8) begin
                    if (v_cnt == V_SUM_PERIOD - 1) begin
                        local_state     <= idle             ;
                    end else begin
                        local_state     <= v_back_blank     ;
                    end
                end else begin
                    local_state         <= v_back_blank     ;
                end
            end
                default: begin
                    local_state         <= idle             ;
                end
            endcase
        end
    end


    always @(posedge clk ) begin
        if (rst) begin
            BRAM_line_cnt               <=       2'b0            ;
        end 
        else begin
            if (h_cnt == H_SUM_PERIOD - 8) begin
                BRAM_line_cnt           <=      BRAM_line_cnt + 1;
            end
            else begin
                BRAM_line_cnt           <=      BRAM_line_cnt    ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            o_Vsync                     <=      1'b0             ;
        end 
        else begin
            if (o_frame_finish_pulse) begin
                o_Vsync                 <=      1'b0             ;
            end
            else if (o_line_finish_pulse) begin
                o_Vsync                 <=      1'b1             ;
            end 
            else begin
                o_Vsync                 <=      o_Vsync          ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            h_cnt                           <=      'b0                     ;
        end 
        else begin
            if (cnt_ena) begin
                if (h_cnt >= H_SUM_PERIOD - 8) begin
                    h_cnt                   <=      'b0                     ;
                end 
                else begin
                    h_cnt                   <=      h_cnt  +  8             ;
                end
            end
            else begin
                h_cnt                       <=      'b0                     ;
            end
        end
    end

    assign Bram_rd_ena = (local_state == roi_h_data);

    always @(posedge clk ) begin
        if (rst) begin
            o_Hsync                         <=      1'b0                    ;
        end
        else begin
            o_Hsync                         <=      Bram_rd_ena             ;
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            o_line_transfer_finish          <=      1'b0                    ;
        end 
        else begin
            if (h_cnt == H_SUM_PERIOD - 8) begin
                if (BRAM_line_cnt == 2'b11) begin
                    o_line_transfer_finish  <=      1'b1                    ;
                end 
                else begin
                    o_line_transfer_finish  <=      1'b0                    ;
                end
            end 
            else begin
                o_line_transfer_finish      <=      1'b0                    ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            v_cnt                           <=          'b0                 ;
        end
        else begin
            if (h_cnt == H_SUM_PERIOD - 8) begin
                if (v_cnt == V_SUM_PERIOD - 1) begin
                    v_cnt                   <=          'b0                 ;    
                end 
                else begin
                    v_cnt                   <=      v_cnt + 1               ;
                end
            end 
            else begin
                v_cnt                       <=      v_cnt                   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            frame_finish                    <=      1'b0                    ;
        end
        else begin
            if (h_cnt == H_SUM_PERIOD - 8) begin
                if (v_cnt == V_SUM_PERIOD - 1) begin
                    frame_finish            <=      1'b1                    ;
                end 
                else begin
                    frame_finish            <=      1'b0                    ;
                end
            end 
            else begin
                frame_finish                <=      1'b0                    ;
            end
        end
    end

    U0_SinglePulse Frame_finish_pulse_generate(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .bi_dir                                    (frame_finish               ),
    .bi_pulse                                  (o_frame_finish_pulse       ) 
    );

    U0_SinglePulse Line_trans_finish_pulse_generate(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    
    .bi_dir                                    (o_line_transfer_finish     ),
    .bi_pulse                                  (o_line_transfer_finish_pulse) 
    );

endmodule                                                          
