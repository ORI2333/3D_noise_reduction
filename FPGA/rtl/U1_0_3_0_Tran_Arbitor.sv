`timescale 1ns / 1ps 
/*
�?要加�?层�?�辑：要求先判满足last条件的数据进行传�?
*/


module U1_0_3_0_Tran_Arbitor #(
    parameter                 CH_NUM                      = 3     ,
    parameter                 ONCE_LENTH                  = 16   
)(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       start                       ,//每更新一次grant信号之后就会start�?�?
    input                     [  19: 0]         trans_lenth     [CH_NUM-1:0],//定�??
    input                     [   6: 0]         FIFO_stack_cnt  [CH_NUM-1:0],//动�??
    output  reg               [  19: 0]         trans_cnt       [CH_NUM-1:0],//现阶段三个FIFO的传输�?�量
    input                     [   2: 0]         FIFO_granted                ,
    output  wire                                last_transaction[CH_NUM-1:0],//动�??
    input                    [CH_NUM-1:0]       trans_finish                ,//外部的传输结束信�?
    output  reg              [CH_NUM-1:0]       Select_FIFO_id              ,
    output                                      Arbitor_flag                 //表示本次仲裁有结果了
);


    localparam                IDLE            = 0                           ;
    localparam                WAIT            = 1                           ;
    localparam                FINISH          = 2                           ;


    reg                       [   1: 0]         state_r                     ;
    wire                      [  22: 0]         sort_src        [       2:0];
    reg                       [CH_NUM-1: 0]     sorted_fifo_id_r[CH_NUM-1:0];
    wire                      [  22: 0]         sort            [CH_NUM-1:0];
    wire                                        sort_over_flag              ;
    reg                                         Arbitor_flag_r              ;
    wire                                        you_can_trans   [CH_NUM-1:0];

    assign       sort_src[0]             =     {3'b001,trans_lenth[0]>>3}      ;
    assign       sort_src[1]             =     {3'b010,trans_lenth[1]>>3}      ;
    assign       sort_src[2]             =     {3'b100,trans_lenth[2]>>3}      ;

    genvar   i  ;

    U0_SinglePulse u_U0_SinglePulse(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .pos_dir                                   (Arbitor_flag_r             ),
    .pos_pulse                                 (Arbitor_flag               ) 
    );

    generate
        for (i = 0;i < CH_NUM; i = i + 1) begin
            assign last_transaction[i]   = ((trans_cnt[i] + ONCE_LENTH) >= trans_lenth[i]) && (FIFO_stack_cnt[i] + trans_cnt[i] >= trans_lenth[i]);
            assign you_can_trans   [i]   = FIFO_granted[i] & (FIFO_stack_cnt[i] >= ONCE_LENTH) ;

            always @(posedge clk )begin
                if (rst) begin
                    trans_cnt[i]        <=    'b0                           ;
                end
                else if (trans_finish[i]) begin
                    if (last_transaction[i]) begin
                        trans_cnt[i]    <=    'b0                           ;
                    end 
                    else begin
                        trans_cnt[i]    <=    trans_cnt[i] + ONCE_LENTH     ;
                    end
                end 
                else begin
                    trans_cnt[i]        <=    trans_cnt[i]                  ;
                end
            end

            always @(posedge clk )begin
                if (rst) begin
                    sorted_fifo_id_r[i]     <=    'b0                       ;
                end
                else begin
                    if (sort_over_flag) begin
                        sorted_fifo_id_r[i] <= sort[i][22:20]               ;
                    end else begin
                        sorted_fifo_id_r[i] <= sorted_fifo_id_r[i]          ;
                    end
                end
            end
        end
    endgenerate



    always @(posedge clk ) begin
        if (rst) begin
            state_r                         <=      IDLE                    ;
        end
        else begin
            case (state_r)
                IDLE   : begin
                        if (start) begin
                            state_r         <=      WAIT                    ;
                        end
                        else begin
                            state_r         <=      IDLE                    ;
                        end
                end
                WAIT   : begin
                        if (sort_over_flag) begin
                            state_r         <=      FINISH                  ;
                        end
                        else begin
                            state_r         <=      WAIT                    ;
                        end
                end
                FINISH : begin
                        if (last_transaction[0] | last_transaction[1] | last_transaction[2]) begin
                            state_r         <=      IDLE                    ;
                        end
                        else if (you_can_trans[0] | you_can_trans[1] | you_can_trans[2]) begin
                            state_r         <=      IDLE                    ;
                        end
                        else begin
                            state_r         <=      FINISH                  ;
                        end
                end
                default: begin
                        state_r             <=      IDLE                    ;
                end
            endcase
        end
    end

    U1_0_3_0_0_Sort#(
        .D_WIDTH                                   (23                     ),
        .CH_NUM                                    (3                      )
    )
     u_U1_0_3_0_0_Sort(
        .clk                                       (clk                    ),
        .rst                                       (rst                    ),
        .src_val                                   (start                  ),
        .src                                       (sort_src               ),
        .sort                                      (sort                   ),
        .sort_over_flag                            (sort_over_flag         )
    );


    always @(posedge clk )begin
        if (rst) begin
            Select_FIFO_id                  <=       'b0                    ;
            Arbitor_flag_r                  <=      1'b0                    ;
        end
        else begin
            if ((state_r == FINISH)) begin
                if (you_can_trans[0]|last_transaction[0]) begin
                    Select_FIFO_id          <=      sorted_fifo_id_r[0]     ;
                    Arbitor_flag_r          <=      1'b1                    ;
                end
                else if (you_can_trans[1]|last_transaction[1]) begin
                    Select_FIFO_id          <=      sorted_fifo_id_r[1]     ;
                    Arbitor_flag_r          <=      1'b1                    ;
                end
                else if (you_can_trans[2]|last_transaction[2]) begin
                    Select_FIFO_id          <=      sorted_fifo_id_r[2]     ;
                    Arbitor_flag_r          <=      1'b1                    ;
                end
                else begin
                    Select_FIFO_id          <=       'b0                    ;
                    Arbitor_flag_r          <=      1'b0                    ;
                end
            end
            else begin
                Arbitor_flag_r              <=      1'b0                    ;
                Select_FIFO_id              <=      'b0                     ;
            end
        end
    end




endmodule                                                          
