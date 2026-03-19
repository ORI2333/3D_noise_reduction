`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/01/21 10:11:03
// Design Name: 
// Module Name: U7_1_0_3_Temporal_algorithm
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


module U6_1_Temporal_algorithm #(
    parameter                 H_DISP                      =       480,                              
    parameter                 V_DISP                      =       480,
    parameter                 CHANNEL_NUM                 =       8
)(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       ena                         ,
    input                     [   7: 0]         macroblock_num              ,
    input                     [   7: 0]         tmp_weight                  ,

    output reg                                  rd_ena                      ,
    output reg                [  13: 0]         generated_rd_addr  [CHANNEL_NUM -1: 0],
    input                     [   7: 0]         d_in_proc          [CHANNEL_NUM -1: 0],
    input                     [   7: 0]         d_in_match         [CHANNEL_NUM -1: 0],

    output reg                [   7: 0]         d_out              [CHANNEL_NUM -1: 0],
    output reg                                  d_out_vld          [CHANNEL_NUM -1: 0],
    output reg                [  12: 0]         d_out_addr         [CHANNEL_NUM -1: 0],

    output reg                                  algo_finish_flag            ,
    input                                       finish_clr                   

    );

    localparam                          idle                = 0             ;
    localparam                          data_fetch          = 1             ;

    reg                [  11: 0]        macroblock_num_r                    ;
    reg                [   7: 0]        tmp_weight_r                        ;

    reg                [   1: 0]        c_st                                ;
    reg                [  13: 0]        address_gen   [CHANNEL_NUM -1: 0][ 1: 0];
    reg                [   0: 0]        addr_idx                            ;
    reg                [   0: 0]        addr_out_idx                        ;
    reg                                 rd_ena_d                            ;



    always @(posedge clk ) begin
        if (rst) begin
            macroblock_num_r            <=      'b0                         ;
            tmp_weight_r                <=      'b0                         ;
        end 
        else if (finish_clr) begin
            macroblock_num_r            <=      'b0                         ;
            tmp_weight_r                <=      'b0                         ;
        end
        else begin
            if (ena) begin
                macroblock_num_r        <=      macroblock_num              ;
                tmp_weight_r            <=      tmp_weight                  ;
            end 
            else begin
                macroblock_num_r        <=      macroblock_num_r            ;
                tmp_weight_r            <=      tmp_weight_r                ;
            end
        end
    end


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            c_st                        <=      idle                        ;
            rd_ena                      <=      1'b0                        ;
        end 
        else begin
            case (c_st)
                idle: begin
                    if (ena) begin
                        c_st            <=      data_fetch                  ;
                    end 
                    else begin
                        c_st            <=      idle                        ;
                    end
                end
                data_fetch: begin
                    if (addr_idx >= 1'b1) begin
                        c_st            <=      idle                        ;
                        rd_ena          <=      1'b0                        ;
                    end
                    else begin
                        c_st            <=      data_fetch                  ;
                        rd_ena          <=      1'b1                        ;
                    end
                end
                default: begin
                    c_st                <=      idle                        ;
                end
            endcase
        end
    end


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            address_gen[0][0]           <=       'b0                                       ;
            address_gen[1][0]           <=       'b0                                       ;
            address_gen[2][0]           <=       'b0                                       ;
            address_gen[3][0]           <=       'b0                                       ;
            address_gen[4][0]           <=       'b0                                       ;
            address_gen[5][0]           <=       'b0                                       ;
            address_gen[6][0]           <=       'b0                                       ;
            address_gen[7][0]           <=       'b0                                       ;
            address_gen[0][1]           <=       'b0                                       ;
            address_gen[1][1]           <=       'b0                                       ;
            address_gen[2][1]           <=       'b0                                       ;
            address_gen[3][1]           <=       'b0                                       ;
            address_gen[4][1]           <=       'b0                                       ;
            address_gen[5][1]           <=       'b0                                       ;
            address_gen[6][1]           <=       'b0                                       ;
            address_gen[7][1]           <=       'b0                                       ;
        end
        else begin
            if (ena) begin
                address_gen[0][0]       <=       (macroblock_num << 2)                    ;
                address_gen[1][0]       <=       (macroblock_num << 2) + 1                ;
                address_gen[2][0]       <=       (macroblock_num << 2) + 2                ;
                address_gen[3][0]       <=       (macroblock_num << 2) + 3                ;
                address_gen[4][0]       <=       (macroblock_num << 2)      +  H_DISP     ;
                address_gen[5][0]       <=       (macroblock_num << 2) + 1  +  H_DISP     ;
                address_gen[6][0]       <=       (macroblock_num << 2) + 2  +  H_DISP     ;
                address_gen[7][0]       <=       (macroblock_num << 2) + 3  +  H_DISP     ;
                address_gen[0][1]       <=       (macroblock_num << 2)      +  H_DISP * 2 ;
                address_gen[1][1]       <=       (macroblock_num << 2) + 1  +  H_DISP * 2 ;
                address_gen[2][1]       <=       (macroblock_num << 2) + 2  +  H_DISP * 2 ;
                address_gen[3][1]       <=       (macroblock_num << 2) + 3  +  H_DISP * 2 ;
                address_gen[4][1]       <=       (macroblock_num << 2)      +  H_DISP * 3 ;
                address_gen[5][1]       <=       (macroblock_num << 2) + 1  +  H_DISP * 3 ;
                address_gen[6][1]       <=       (macroblock_num << 2) + 2  +  H_DISP * 3 ;
                address_gen[7][1]       <=       (macroblock_num << 2) + 3  +  H_DISP * 3 ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            addr_idx                       <=          'b0          ;
        end 
        else begin
            if (rd_ena) begin
                addr_idx                   <=          addr_idx + 1 ;
            end 
            else begin
                addr_idx                   <=          addr_idx     ;
            end
        end
    end

    genvar a;

    generate
        for (a = 0; a < CHANNEL_NUM; a = a + 1) begin
            always @(posedge clk ) 
            begin
                if (rst) begin
                    generated_rd_addr[a]   <=   'b0                 ;
                end 
                else begin
                    if (c_st == data_fetch) begin
                        generated_rd_addr[a]<=   address_gen[a][addr_idx];
                    end
                    else begin
                        generated_rd_addr[a]<=   generated_rd_addr[a];
                    end
                end
            end
        end
    endgenerate


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            addr_out_idx                <=          'b0                     ;
        end 
        else begin
            if (rd_ena_d) begin
                addr_out_idx            <=          addr_out_idx + 1        ;
            end 
            else begin
                addr_out_idx            <=          addr_out_idx            ;
            end
        end
    end


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            rd_ena_d                    <=      1'b0                        ;
        end 
        else begin
            rd_ena_d                    <=      rd_ena                      ;
        end
    end



    wire                      [  15: 0]         calculated_data  [CHANNEL_NUM -1: 0];

    genvar c;

    generate
        for (c = 0;c < CHANNEL_NUM ;c = c + 1) begin

            always @(posedge clk ) begin
                if (rst | finish_clr) begin
                    d_out_vld[c]           <=      1'b0                        ;
        
                end 
                else begin
                    d_out_vld[c]           <=      rd_ena_d                    ;
                end
            end

            assign calculated_data[c] = ((d_in_proc[c] * (6'b100000 - tmp_weight_r[5:0])) >> 5) + ((d_in_match[c] * tmp_weight_r[5:0]) >> 5);

            always @(posedge clk ) begin
                if (rst | finish_clr) begin
                    d_out[c]               <=      'b0                      ;
                end 
                else begin
                    if (rd_ena_d) begin//128 6
                        d_out[c]           <=      calculated_data[c][7:0]  ;    
                    end
                    else begin
                        d_out[c]           <=      d_out[c]                 ;
                    end
                end
            end

            always @(posedge clk ) begin
                if (rst | finish_clr) begin
                    d_out_addr[c]          <=      'b0                      ;
                end 
                else begin
                    if (rd_ena_d) begin
                        d_out_addr[c]      <=      address_gen[c][addr_out_idx][12:0];
                    end
                    else begin
                        d_out_addr[c]      <=      d_out_addr[c]            ;
                    end
                end
            end
        end
    endgenerate


    always @(posedge clk ) begin
        if (rst) begin
            algo_finish_flag            <=      'b0                         ;
        end 
        else begin
            if (addr_out_idx == 4'h1) begin
                algo_finish_flag        <=      1'b1                        ;
            end 
            else begin
                algo_finish_flag        <=      1'b0                        ;
            end    
        end
    end

endmodule
