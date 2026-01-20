`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/01/21 10:11:03
// Design Name: 
// Module Name: U7_1_0_1_MotionEstimate_ThresholdDetect
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//{ signal: [
//    { name: "clk                  " , wave:"P..|...|.............|...|..." },
//    { name: "rst                  " , wave:"lhl|...|.............|...|..." },
//    { name: "start                " , wave:"l..|.hl|.............|...|..." },
//    { name: "image_height         " , wave:"x..|.3x|.............|...|..." ,data:["V_DISP"]},
//    { name: "image_width          " , wave:"x..|.3x|.............|...|..." ,data:["H_DISP"]},
//    { name: "Macro_Block_Threshold" , wave:"x..|.4x|.............|...|..." ,data:["cfg0"]},
//    { name: "proc_block_addr      " , wave:"x..|.5x|.............|...|..." ,data:["BRAM_addr"]},
//    { name: "rd_ena_wire          " , wave:"l..|...|.h.........l.|...|..." },
//    { name: "rd_addr_wire         " , wave:"x..|...|.345678345.x.|...|..." ,data:["addr0","addr1","addr2","addr3","addr4","addr5","addr6","addr7","addr8"]},
//    { name: "rd_type              " , wave:"x..|...|.3.........x.|...|..." ,data:["type0"]},
//    { name: "d_in                 " , wave:"x..|...|...345678345x|...|..." ,data:["din0","din1","din2","din3","din4","din5","din6","din7","din8"]},
//    { name: "select_Temporal      " , wave:"x..|...|.............|.3x|..." ,data:["sel0"]},
//    { name: "ME_TD_finish_flag    " , wave:"l..|...|.............|.hl|..." },
//    { name: "finish_clr           " , wave:"l..|...|.............|...|.hl" }
//  ],
//  head: {
//    text: 'MotionEstimate_ThresholdDetect',
//    every: 1
//  },
//  config: { hscale: 1 }
//}


module U4_MotionEstimate_ThresholdDetect#(
    parameter                 H_DISP                      = 480   ,
    parameter                 V_DISP                      = 480   
)
(
    input                                       clk                         ,//! 时钟
    input                                       rst                         ,//! 复位

    input                                       start                       ,//! 系统启动信号，检测单个宏块
    input                     [  14: 0]         proc_block_addr             ,//! 处理帧的对应宏块地址
    input                     [  11: 0]         macro_block_threshold       ,

    output wire                                 rd_ena_wire                 ,//! 读取使能
    output wire               [  15: 0]         rd_addr_wire                ,//! 读取地址
    output reg                [   1: 0]         rd_type                     ,//! 读取类型，00为原图，01为匹配下采样图，10为匹配宏块图
    
    input                     [  11: 0]         d_in                        ,//! 读取的数据输入

    output reg                                  select_Temporal             ,//! 结果输出选择时域滤波
    output wire                                 ME_TD_finish_flag           ,//! 单个宏块检测完成
    input                                       finish_clr                   //! 清除系统状态

    );

    /*
    1.收到启动脉冲，优先根据读取的块地址读出处理数据
    2.利用块地址生成一组匹配地址
    3.输出匹配地址，并接受地址数据
    4.对地址进行最优化计算，并循环读取直到最优，要求：大圈不超过3次，小圈直接跳转上采样
    5.计算出K相似度，并进行阈值判断
    6.finish
    */

    //0001111111110000 ena
    //0000111111111000 ena_d1
    //0000011111111100 ena_d2
    //00000ddddddd0000
    //打两拍子延迟，然后拿原信号和d2信号作与，得出来的信号可以作为写信号
    //然后counter就可以简化，无论是生成match还是process都可以简化成一个计数器
    //接受数据可以采用移位寄存器，也是受到与运算之后的ena信号控制
    //激发读逻辑的ena可以使用状态机控制

//=====================================================================
//  FSM

    localparam                idle                        = 3'b000          ;
    localparam                fetch_process_block         = 3'b001          ;
    localparam                fetch_matching_address      = 3'b011          ;
    localparam                fetch_matching_block        = 3'b010          ;
    localparam                best_SAD_Vector             = 3'b110          ;


    reg                       [   2: 0]         state_r                     ;

    reg                       [  14: 0]         proc_block_addr_r           ;

    reg                       [   7: 0]         rd_addr_site_x              ;
    reg                       [   7: 0]         rd_addr_site_y              ;
 
    reg                                         start_tx                    ;
    wire                                        start_tx_pulse              ;


    wire                                        cal_finish_flag             ;
    wire                                        cal_finsih_flag_clr         ;

    wire                                        MSV_flag                    ;
    wire                                        MSV_clr_pulse               ;

    reg                                         ME_TD_finish_flag_r         ;

    reg                                         Addr_gen_ena                ;
    wire                                        Addr_gen_ena_pulse          ;

    reg                                         MSV_start                   ;
    wire                                        MSV_start_pulse             ;

    reg                       [   3: 0]         valid_addr_number           ;
    reg                                         rd_ena_src                  ;
    reg                       [   3: 0]         tx_data_counter             ;
    reg                       [   1: 0]         find_cnt                    ;
    wire                      [   3: 0]         minimum_id                  ;
    reg                       [   3: 0]         minimum_id_r                ;
    reg                       [   5: 0]         vec_col_r                   ;
    reg                       [   5: 0]         vec_row_r                   ;
    reg                       [  11: 0]         SAD                         ;
    wire                      [  11: 0]         SAD_Wire                    ;
    wire                                        address_0_ena               ;
    wire                                        address_1_ena               ;
    wire                                        address_2_ena               ;
    wire                                        address_3_ena               ;
    wire                                        address_4_ena               ;
    wire                                        address_5_ena               ;
    wire                                        address_6_ena               ;
    wire                                        address_7_ena               ;
    wire                                        address_8_ena               ;

    reg                       [   8: 0]         address_ena_r               ;

    reg                       [  14: 0]         gen_address_stream[8:0]     ;

    wire                      [  14: 0]         address_0                   ;
    wire                      [  14: 0]         address_1                   ;
    wire                      [  14: 0]         address_2                   ;
    wire                      [  14: 0]         address_3                   ;
    wire                      [  14: 0]         address_4                   ;
    wire                      [  14: 0]         address_5                   ;
    wire                      [  14: 0]         address_6                   ;
    wire                      [  14: 0]         address_7                   ;
    wire                      [  14: 0]         address_8                   ;


    reg                       [  14: 0]         base_addr                   ;

    reg                       [   1: 0]         gen_type                    ;
    reg                       [  11: 0]         receive_data_stream[8:0]    ;
    reg                       [  11: 0]         process_block_data          ;
    reg                       [   1: 0]         rd_ena_d                    ;
    wire                                        receive_data_ena            ;
    reg                       [   3: 0]         rx_data_counter             ;
    reg                       [   3: 0]         tx_idx                      ;

//=====================================================================

    assign                              rd_ena_wire             = rd_ena_src;

    always @(posedge clk ) begin                               
        if(rst | finish_clr)begin                       
            proc_block_addr_r                   <=      'b0                 ;
        end                         
        else begin                       
            if (start) begin
                proc_block_addr_r               <=      proc_block_addr     ;
            end 
            else begin
                proc_block_addr_r               <=      proc_block_addr_r   ;    
            end
        end                         
    end


    U0_SinglePulse_SubSys u_U0_SinglePulse_SubSys(
        .clk                                (clk                       ),
        .rst                                (rst                       ),
        .pos_dir0                           (start_tx                  ),
        .pos_pulse0                         (start_tx_pulse            ),
        .pos_dir1                           (cal_finish_flag           ),
        .pos_pulse1                         (cal_finsih_flag_clr       ),
        .pos_dir2                           (MSV_flag                  ),
        .pos_pulse2                         (MSV_clr_pulse             ),
        .pos_dir3                           (ME_TD_finish_flag_r       ),
        .pos_pulse3                         (ME_TD_finish_flag         ),
        .pos_dir4                           (Addr_gen_ena              ),
        .pos_pulse4                         (Addr_gen_ena_pulse        ),
        .pos_dir5                           (MSV_start                 ),
        .pos_pulse5                         (MSV_start_pulse           )
    );

    always @(posedge clk ) begin
        if (rst) begin
            state_r                             <=      idle                            ;
            start_tx                            <=      1'b0                            ;
            Addr_gen_ena                        <=      'b0                             ;
            gen_type                            <=      'b0                             ;
            MSV_start                           <=      'b0                             ;
            rd_type                             <=      'b0                             ;
        end
        else begin
            case (state_r)
                idle: begin
                    if (start) begin
                        state_r                 <=      fetch_process_block             ;

                        start_tx                <=      1'b1                            ;
                        rd_type                 <=      2'b00                           ;  
                    end
                    else begin
                        state_r                 <=      idle                            ;
                    end
                end
                fetch_process_block:begin
                    start_tx                    <=      1'b0                            ;

                    if (rd_ena_d[0] & rd_ena_d[1]) begin
                        state_r                 <=      fetch_matching_address          ;

                        //启动地址生成大圈模式-match
                        Addr_gen_ena            <=      1'b1                            ;
                        gen_type                <=      2'b00                           ;
                        rd_type                 <=      2'b01                           ;
                        base_addr               <=      proc_block_addr_r               ;
                    end 
                    else begin
                        state_r                 <=      fetch_process_block             ;
                    end
                end
                fetch_matching_address: begin
                    Addr_gen_ena                <=      1'b0                            ;

                    if (cal_finish_flag) begin
                        state_r                 <=      fetch_matching_block            ;

                        //生成ena信号
                        start_tx                <=      1'b1                            ;
                    end 
                    else begin
                        state_r                 <=      fetch_matching_address          ;
                    end
                end
                fetch_matching_block: begin
                    start_tx                    <=      1'b0                            ;


                    if (tx_data_counter == valid_addr_number + 2 - 2) begin//接受完毕
                        state_r                 <=      best_SAD_Vector                 ;
                        
                        //启动MSV
                        MSV_start               <=      1'b1                            ;
                    end
                    else begin
                        state_r                 <=      fetch_matching_block            ;
                    end
                end
                best_SAD_Vector: begin
                    MSV_start                   <=      1'b0                            ;

                    if (MSV_flag) begin
                        if (gen_type[0] == gen_type[1]) begin//9
                            if (minimum_id == 4'h0 || (find_cnt == 2'b01)) begin
                                state_r         <=      fetch_matching_address          ;

                                /*写一个逻辑，要求换状态，并触发地址生成*/
                                Addr_gen_ena    <=      1'b1                            ;
                                gen_type        <=      2'b01                           ;
                                rd_type         <=      2'b01                           ;  
                                base_addr       <=      gen_address_stream[minimum_id]  ;                            
                            end
                            else begin
                                state_r         <=      fetch_matching_address          ;

                                //换对应的地址，然后启动地址生成
                                Addr_gen_ena    <=      1'b1                            ;
                                gen_type        <=      2'b00                           ;
                                rd_type         <=      2'b01                           ;  
                                base_addr       <=      gen_address_stream[minimum_id]  ;
                            end
                        end
                        else if (gen_type == 2'b01) begin//5
                            state_r             <=      fetch_matching_address          ;
                            /*写一个逻辑，要求换状态，并触发地址生成*/
                            Addr_gen_ena        <=      1'b1                            ;
                            rd_type             <=      2'b10                           ;  
                            gen_type            <=      2'b10                           ;
                            base_addr           <=      gen_address_stream[minimum_id]  ;
                        end
                        else begin//4
                            gen_type            <=      2'b00                           ;
                            rd_type             <=      2'b00                           ;  
                            state_r             <=      idle                            ;

                        end
                    end 
                    else begin
                        state_r                 <=      best_SAD_Vector                 ;
                    end
                end
                default:begin
                    state_r                     <=      idle                            ;
                end 
            endcase
        end
    end

//---------------------------------------------------------------------------------------
//                                                                                     
//---------------------------------------------------------------------------------------



    u_2_to_1_MUX#(
    .D_WIDTH                                   (16                         ) 
    )
    u_u_2_to_1_MUX_rd_address(
    .i_port0                                   (site_r[tx_idx]             ),
    .i_port1                                   ({rd_addr_site_y,rd_addr_site_x}),
    .sel                                       (state_r == fetch_process_block),
    .o_port_sel                                (rd_addr_wire               ) 
    );

    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            rd_addr_site_y                      <=      'b0                 ;
        end 
        else begin
            if (start) begin
                rd_addr_site_y                  <=      proc_block_addr / (H_DISP/4) ;
            end 
            else begin
                rd_addr_site_y                  <=      proc_block_addr %  (H_DISP/4);
            end    
        end
    end


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            valid_addr_number           <=      'b0                         ;
        end 
        else begin
            if (start) begin
                valid_addr_number       <=      4'h1                        ;
            end
            else if (cal_finish_flag) begin
                if (gen_type[0] == gen_type[1]) begin
                    valid_addr_number   <=      4'ha                        ;  
                end
                else if (gen_type == 2'b01) begin
                    valid_addr_number   <=      4'h6                        ;
                end
                else begin
                    valid_addr_number   <=      4'h5                        ;
                end
            end
            else begin
                valid_addr_number       <=      valid_addr_number           ;
            end
        end
    end


    always @(posedge clk ) begin                               
        if(rst | finish_clr)begin                       
            rd_ena_src                          <=      1'b0                ;
        end                         
        else begin
            if (start_tx_pulse) begin
                rd_ena_src                      <=      1'b1                ;
            end 
            else if (tx_data_counter == valid_addr_number + 2 - 2) begin//这里是处理掉两个延迟
                rd_ena_src                      <=      1'b0                ;
            end
            else begin
                rd_ena_src                      <=      rd_ena_src          ;
            end
        end
    end


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            tx_data_counter                <=    'b0                    ;
        end
        else begin
            if (rd_ena_src) begin
                if (tx_data_counter == valid_addr_number + 2 - 2) begin
                    tx_data_counter        <=    'b0                    ;
                end
                else begin
                    tx_data_counter        <=    tx_data_counter + 1    ;
                end
            end
            else begin
                tx_data_counter            <=    tx_data_counter        ;
            end
        end
    end


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            tx_idx                  <=          'b0                 ;
        end 
        else begin
            if ((state_r == fetch_process_block)) begin
                tx_idx              <=          'b0                 ;
            end
            else begin
                if (tx_data_counter >= valid_addr_number - 2) begin
                    tx_idx          <=          'b0                 ;
                end
                else if (rd_ena_src) begin
                    tx_idx          <=          tx_idx  + 1         ;
                end 
                else begin
                    tx_idx          <=          tx_idx              ;    
                end
            end
        end
    end


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            rx_data_counter                <=    'b0                    ;
        end
        else begin
            if (receive_data_ena) begin
                if (rx_data_counter == valid_addr_number - 2) begin
                    rx_data_counter        <=    'b0                    ;
                end
                else begin
                    rx_data_counter        <=    rx_data_counter + 1    ;
                end
            end
            else begin
                rx_data_counter            <=    rx_data_counter        ;
            end
        end
    end
    

    assign                              receive_data_ena            = rd_ena_d[1] & rd_ena_src;


    always @(posedge clk ) begin                               
        if(rst | finish_clr)begin                       
            rd_ena_d[0]                         <=      1'b0                ;
            rd_ena_d[1]                         <=      1'b0                ;
        end                         
        else begin
            rd_ena_d[0]                         <=      rd_ena_src          ;
            rd_ena_d[1]                         <=      rd_ena_d[0]         ;
        end                         
    end



    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            process_block_data                              <=    12'b0    ;
            receive_data_stream[0]                          <=    12'b0    ;
            receive_data_stream[1]                          <=    12'b0    ;
            receive_data_stream[2]                          <=    12'b0    ;
            receive_data_stream[3]                          <=    12'b0    ;
            receive_data_stream[4]                          <=    12'b0    ;
            receive_data_stream[5]                          <=    12'b0    ;
            receive_data_stream[6]                          <=    12'b0    ;
            receive_data_stream[7]                          <=    12'b0    ;
            receive_data_stream[8]                          <=    12'b0    ;
        end
        else begin
            if (state_r == fetch_process_block) begin
                if (rd_ena_d[0] & rd_ena_d[1]) begin
                    process_block_data                      <=    d_in     ;
                end 
                else begin
                    process_block_data                      <=  process_block_data;
                end
            end 
            else if (receive_data_ena) begin
                receive_data_stream[rx_data_counter]        <=    d_in     ; 
            end 
            else begin
                receive_data_stream[0]                      <=    receive_data_stream[0];
                receive_data_stream[1]                      <=    receive_data_stream[1];
                receive_data_stream[2]                      <=    receive_data_stream[2];
                receive_data_stream[3]                      <=    receive_data_stream[3];
                receive_data_stream[4]                      <=    receive_data_stream[4];
                receive_data_stream[5]                      <=    receive_data_stream[5];
                receive_data_stream[6]                      <=    receive_data_stream[6];
                receive_data_stream[7]                      <=    receive_data_stream[7];
                receive_data_stream[8]                      <=    receive_data_stream[8];
            end
        end
    end


//---------------------------------------------------------------------------------------
//                                                                                     
//---------------------------------------------------------------------------------------



    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            gen_address_stream[0]      <=      'b0                  ;
            gen_address_stream[1]      <=      'b0                  ;
            gen_address_stream[2]      <=      'b0                  ;
            gen_address_stream[3]      <=      'b0                  ;
            gen_address_stream[4]      <=      'b0                  ;
            gen_address_stream[5]      <=      'b0                  ;
            gen_address_stream[6]      <=      'b0                  ;
            gen_address_stream[7]      <=      'b0                  ;
            gen_address_stream[8]      <=      'b0                  ;
        end 
        else begin
            if (cal_finish_flag) begin
                gen_address_stream[0]  <=    address_0              ;     
                gen_address_stream[1]  <=    address_1              ;     
                gen_address_stream[2]  <=    address_2              ;     
                gen_address_stream[3]  <=    address_3              ;     
                gen_address_stream[4]  <=    address_4              ;     
                gen_address_stream[5]  <=    address_5              ;     
                gen_address_stream[6]  <=    address_6              ;     
                gen_address_stream[7]  <=    address_7              ;     
                gen_address_stream[8]  <=    address_8              ;     
            end 
            else begin
                gen_address_stream[0]  <=   gen_address_stream[0]   ;
                gen_address_stream[1]  <=   gen_address_stream[1]   ;
                gen_address_stream[2]  <=   gen_address_stream[2]   ;
                gen_address_stream[3]  <=   gen_address_stream[3]   ;
                gen_address_stream[4]  <=   gen_address_stream[4]   ;
                gen_address_stream[5]  <=   gen_address_stream[5]   ;
                gen_address_stream[6]  <=   gen_address_stream[6]   ;
                gen_address_stream[7]  <=   gen_address_stream[7]   ;
                gen_address_stream[8]  <=   gen_address_stream[8]   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            address_ena_r[0]           <=      'b0                  ;
            address_ena_r[1]           <=      'b0                  ;
            address_ena_r[2]           <=      'b0                  ;
            address_ena_r[3]           <=      'b0                  ;
            address_ena_r[4]           <=      'b0                  ;
            address_ena_r[5]           <=      'b0                  ;
            address_ena_r[6]           <=      'b0                  ;
            address_ena_r[7]           <=      'b0                  ;
            address_ena_r[8]           <=      'b0                  ;
        end 
        else begin
            if (cal_finish_flag) begin
                address_ena_r[0]       <=    address_0_ena          ;     
                address_ena_r[1]       <=    address_1_ena          ;     
                address_ena_r[2]       <=    address_2_ena          ;     
                address_ena_r[3]       <=    address_3_ena          ;     
                address_ena_r[4]       <=    address_4_ena          ;     
                address_ena_r[5]       <=    address_5_ena          ;     
                address_ena_r[6]       <=    address_6_ena          ;     
                address_ena_r[7]       <=    address_7_ena          ;     
                address_ena_r[8]       <=    address_8_ena          ;     
            end 
            else begin
                address_ena_r[0]       <=   address_ena_r[0]        ;
                address_ena_r[1]       <=   address_ena_r[1]        ;
                address_ena_r[2]       <=   address_ena_r[2]        ;
                address_ena_r[3]       <=   address_ena_r[3]        ;
                address_ena_r[4]       <=   address_ena_r[4]        ;
                address_ena_r[5]       <=   address_ena_r[5]        ;
                address_ena_r[6]       <=   address_ena_r[6]        ;
                address_ena_r[7]       <=   address_ena_r[7]        ;
                address_ena_r[8]       <=   address_ena_r[8]        ;
            end
        end
    end

    wire                      [  15: 0]         site_0                      ;
    wire                      [  15: 0]         site_1                      ;
    wire                      [  15: 0]         site_2                      ;
    wire                      [  15: 0]         site_3                      ;
    wire                      [  15: 0]         site_4                      ;
    wire                      [  15: 0]         site_5                      ;
    wire                      [  15: 0]         site_6                      ;
    wire                      [  15: 0]         site_7                      ;
    wire                      [  15: 0]         site_8                      ;

    reg                       [  15: 0]         site_r   [8:0]            ;


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            site_r[0]                       <=      'b0                   ;
            site_r[1]                       <=      'b0                   ;
            site_r[2]                       <=      'b0                   ;
            site_r[3]                       <=      'b0                   ;
            site_r[4]                       <=      'b0                   ;
            site_r[5]                       <=      'b0                   ;
            site_r[6]                       <=      'b0                   ;
            site_r[7]                       <=      'b0                   ;
            site_r[8]                       <=      'b0                   ;
        end
        else begin
            if (cal_finish_flag) begin
                site_r[0]                   <=    site_0                  ;
                site_r[1]                   <=    site_1                  ;
                site_r[2]                   <=    site_2                  ;
                site_r[3]                   <=    site_3                  ;
                site_r[4]                   <=    site_4                  ;
                site_r[5]                   <=    site_5                  ;
                site_r[6]                   <=    site_6                  ;
                site_r[7]                   <=    site_7                  ;
                site_r[8]                   <=    site_8                  ;
            end 
            else begin
                site_r[0]                   <=    site_0                  ;
                site_r[1]                   <=    site_1                  ;
                site_r[2]                   <=    site_2                  ;
                site_r[3]                   <=    site_3                  ;
                site_r[4]                   <=    site_4                  ;
                site_r[5]                   <=    site_5                  ;
                site_r[6]                   <=    site_6                  ;
                site_r[7]                   <=    site_7                  ;
                site_r[8]                   <=    site_8                  ;
            end
        end
    end


    U4_1_Addr_Gen  #(
    .MB_WIDTH                                  (H_DISP  /4                 ),
    .DS_WIDTH                                  (H_DISP  /8                 ),
    .MB_HEIGHT                                 (V_DISP /4                  ),
    .DS_HEIGHT                                 (V_DISP /8                  ) 

    )u_U4_1_Addr_Gen(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .ena                                       (Addr_gen_ena_pulse         ),
    .gen_type                                  (gen_type                   ),// 00 11 : 9 ; 01: 5 10:4
    .central_address                           (base_addr                  ),

    .cal_finish_flag                           (cal_finish_flag            ),
    .flag_clr                                  (cal_finsih_flag_clr        ),

    .site_0                                    (site_0                     ),
    .site_1                                    (site_1                     ),
    .site_2                                    (site_2                     ),
    .site_3                                    (site_3                     ),
    .site_4                                    (site_4                     ),
    .site_5                                    (site_5                     ),
    .site_6                                    (site_6                     ),
    .site_7                                    (site_7                     ),
    .site_8                                    (site_8                     ),

    .address_0                                 (address_0                  ),
    .address_0_ena                             (address_0_ena              ),
    .address_1                                 (address_1                  ),
    .address_1_ena                             (address_1_ena              ),
    .address_2                                 (address_2                  ),
    .address_2_ena                             (address_2_ena              ),
    .address_3                                 (address_3                  ),
    .address_3_ena                             (address_3_ena              ),
    .address_4                                 (address_4                  ),
    .address_4_ena                             (address_4_ena              ),
    .address_5                                 (address_5                  ),
    .address_5_ena                             (address_5_ena              ),
    .address_6                                 (address_6                  ),
    .address_6_ena                             (address_6_ena              ),
    .address_7                                 (address_7                  ),
    .address_7_ena                             (address_7_ena              ),
    .address_8                                 (address_8                  ),
    .address_8_ena                             (address_8_ena              ) 

    );



    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            vec_col_r                      <=   'b0                         ;
            vec_row_r                      <=   'b0                         ;
            SAD                            <= 12'hfff                       ;
            minimum_id_r                   <=   'hf                         ;
        end 
        else begin
            if (MSV_flag) begin
                vec_col_r                  <= vector_col + vec_col_r        ;
                vec_row_r                  <= vector_row + vec_row_r        ;
                SAD                        <= SAD_Wire                      ;
                minimum_id_r               <= minimum_id                    ;
            end 
            else begin
                vec_col_r                  <= vec_col_r                     ;
                vec_row_r                  <= vec_row_r                     ;
                SAD                        <= SAD                           ;
                minimum_id_r               <= minimum_id_r                  ;
            end
        end
    end



    U4_2_Max_reg_SAD_Vector u_U4_2_Max_reg_SAD_Vector(
        .clk                                    (clk                       ),
        .rst                                    (rst                       ),

        .start                                  (MSV_start_pulse           ),
        .compare_type                           (gen_type                  ),

        .base_blk                               (process_block_data        ),

        .match_blk_0                            (receive_data_stream[0]    ),
        .match_blk_1                            (receive_data_stream[1]    ),
        .match_blk_2                            (receive_data_stream[2]    ),
        .match_blk_3                            (receive_data_stream[3]    ),
        .match_blk_4                            (receive_data_stream[4]    ),
        .match_blk_5                            (receive_data_stream[5]    ),
        .match_blk_6                            (receive_data_stream[6]    ),
        .match_blk_7                            (receive_data_stream[7]    ),
        .match_blk_8                            (receive_data_stream[8]    ),

        .match_blk_ena_0                        (address_ena_r[0]          ),
        .match_blk_ena_1                        (address_ena_r[1]          ),
        .match_blk_ena_2                        (address_ena_r[2]          ),
        .match_blk_ena_3                        (address_ena_r[3]          ),
        .match_blk_ena_4                        (address_ena_r[4]          ),
        .match_blk_ena_5                        (address_ena_r[5]          ),
        .match_blk_ena_6                        (address_ena_r[6]          ),
        .match_blk_ena_7                        (address_ena_r[7]          ),
        .match_blk_ena_8                        (address_ena_r[8]          ),

        .finish_flag                            (MSV_flag                  ),
        .flag_clr                               (MSV_clr_pulse             ),

        .minimum_id                             (minimum_id                ),
        .vector_row                             (vector_row                ),
        .vector_col                             (vector_col                ),
        .SAD                                    (SAD_Wire                  )
    );

    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            find_cnt                <=          2'b0                        ;
        end 
        else begin
            if (MSV_flag) begin
                if (gen_type[0] == gen_type[1]) begin
                    if (minimum_id == 4'h0 || (find_cnt == 2'b01)) begin
                        find_cnt            <=      2'b0                    ;
                    end 
                    else begin
                        find_cnt            <=      find_cnt + 1            ;
                    end
                end
                else begin
                    find_cnt                <=      2'b0                    ;
                end
            end
            else begin
                find_cnt                    <=      find_cnt                ;
            end
        end
    end


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            select_Temporal                 <=      1'b0                    ; 
            ME_TD_finish_flag_r             <=      1'b0                    ;
        end
        else begin
            if (MSV_flag && (gen_type == 2'b10)) begin
                ME_TD_finish_flag_r         <=      1'b1                    ;

                if ((SAD_Wire) < macro_block_threshold) begin//Temporal
                    select_Temporal         <=      1'b1                    ;
                end 
                else begin
                    select_Temporal         <=      1'b0                    ;
                end
            end 
            else begin
                select_Temporal             <=      1'b0                    ;
                ME_TD_finish_flag_r         <=      1'b0                    ;
            end
        end
    end



endmodule
