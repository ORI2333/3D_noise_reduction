`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/01/21 10:11:03
// Design Name: 
// Module Name: U7_1_0_2_Spatial_algorithm
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


module U6_0_Spatial_algorithm #(
    parameter                 H_DISP                      =       480,                              
    parameter                 V_DISP                      =       480,
    parameter                 CHANNEL_NUM                 =       8     
)(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       i_ena_single_pulse          ,
    input                     [  13: 0]         macroblock_num              ,//�����ĵڼ������
    output reg                                  rd_ena                      ,
    output reg                [  11: 0]         generated_rd_addr[CHANNEL_NUM -1: 0],
    input                     [   7: 0]         d_in_proc        [CHANNEL_NUM -1: 0],

    output wire               [   7: 0]         d_out            [CHANNEL_NUM -1: 0],
    output wire                                 d_out_vld        [CHANNEL_NUM -1: 0],
    output wire               [  12: 0]         d_out_addr       [CHANNEL_NUM -1: 0],
    output wire                                 algo_finish_flag            ,
    input                                       finish_clr                   

    );

    localparam                          idle                = 0     ;
    localparam                          data_fetch          = 1     ;
    localparam                          data_get            = 2     ;
    localparam                          data_proc           = 3     ;

    reg                [   1: 0]        c_st                        ;
    reg                [  13: 0]        address_gen   [ 1: 0][CHANNEL_NUM -1: 0];
    reg                [   0: 0]        addr_idx                    ;
    reg                [   0: 0]        addr_idx_d                  ;
    reg                [   0: 0]        addr_out_idx                ;
    reg                                 rd_ena_d                    ;

    reg                [   1: 0]        x                           ;


    
    reg                [   7: 0]        pixel_image    [5:0][5:0]   ;


    always @(*) begin
        pixel_image[0][0]               =       8'b0                ;
        pixel_image[0][1]               =       8'b0                ;
        pixel_image[0][2]               =       8'b0                ;
        pixel_image[0][3]               =       8'b0                ;
        pixel_image[0][4]               =       8'b0                ;
        pixel_image[0][5]               =       8'b0                ;
        pixel_image[5][0]               =       8'b0                ;
        pixel_image[5][1]               =       8'b0                ;
        pixel_image[5][2]               =       8'b0                ;
        pixel_image[5][3]               =       8'b0                ;
        pixel_image[5][4]               =       8'b0                ;
        pixel_image[5][5]               =       8'b0                ;
        pixel_image[1][0]               =       8'b0                ;
        pixel_image[2][0]               =       8'b0                ;
        pixel_image[3][0]               =       8'b0                ;
        pixel_image[4][0]               =       8'b0                ;
        pixel_image[1][5]               =       8'b0                ;
        pixel_image[2][5]               =       8'b0                ;
        pixel_image[3][5]               =       8'b0                ;
        pixel_image[4][5]               =       8'b0                ;
    end


    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            c_st                        <=      idle                ;
            rd_ena                      <=      1'b0                ;
        end 
        else begin
            case (c_st)
                idle: begin
                    if (i_ena_single_pulse) begin
                        c_st            <=      data_fetch          ;
                    end 
                    else begin
                        c_st            <=      idle                ;
                    end
                end
                data_fetch: begin
                    if (addr_idx >= 4'h1) begin
                        c_st            <=      data_get            ;
                        rd_ena          <=      1'b0                ;
                    end
                    else begin
                        c_st            <=      data_fetch          ;
                        rd_ena          <=      1'b1                ;
                    end
                end
                data_get: begin
                    if (addr_idx_d >= 4'h1) begin
                        c_st            <=      data_proc           ;
                    end 
                    else begin
                        c_st            <=      data_get            ;
                    end
                end
                data_proc : begin
                    if ((x == 3)) begin
                        c_st            <=      idle                ;
                    end 
                    else begin
                        c_st            <=      data_proc           ;
                    end
                end
                default: begin
                    c_st                <=      idle                ;
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
            if (i_ena_single_pulse) begin
                address_gen[0][0]       <=       (macroblock_num << 2)                    ;
                address_gen[0][1]       <=       (macroblock_num << 2) + 1                ;
                address_gen[0][2]       <=       (macroblock_num << 2) + 2                ;
                address_gen[0][3]       <=       (macroblock_num << 2) + 3                ;
                address_gen[0][4]       <=       (macroblock_num << 2)      +  H_DISP     ;
                address_gen[0][5]       <=       (macroblock_num << 2) + 1  +  H_DISP     ;
                address_gen[0][6]       <=       (macroblock_num << 2) + 2  +  H_DISP     ;
                address_gen[0][7]       <=       (macroblock_num << 2) + 3  +  H_DISP     ;
                address_gen[1][0]       <=       (macroblock_num << 2)      +  H_DISP * 2 ;
                address_gen[1][1]       <=       (macroblock_num << 2) + 1  +  H_DISP * 2 ;
                address_gen[1][2]       <=       (macroblock_num << 2) + 2  +  H_DISP * 2 ;
                address_gen[1][3]       <=       (macroblock_num << 2) + 3  +  H_DISP * 2 ;
                address_gen[1][4]       <=       (macroblock_num << 2)      +  H_DISP * 3 ;
                address_gen[1][5]       <=       (macroblock_num << 2) + 1  +  H_DISP * 3 ;
                address_gen[1][6]       <=       (macroblock_num << 2) + 2  +  H_DISP * 3 ;
                address_gen[1][7]       <=       (macroblock_num << 2) + 3  +  H_DISP * 3 ;
            end
            else begin
                address_gen[0][0]       <=        address_gen[0][0]                       ;
                address_gen[0][1]       <=        address_gen[1][0]                       ;
                address_gen[0][2]       <=        address_gen[2][0]                       ;
                address_gen[0][3]       <=        address_gen[3][0]                       ;
                address_gen[0][4]       <=        address_gen[4][0]                       ;
                address_gen[0][5]       <=        address_gen[5][0]                       ;
                address_gen[0][6]       <=        address_gen[6][0]                       ;
                address_gen[0][7]       <=        address_gen[7][0]                       ;
                address_gen[1][0]       <=        address_gen[0][1]                       ;
                address_gen[1][1]       <=        address_gen[1][1]                       ;
                address_gen[1][2]       <=        address_gen[2][1]                       ;
                address_gen[1][3]       <=        address_gen[3][1]                       ;
                address_gen[1][4]       <=        address_gen[4][1]                       ;
                address_gen[1][5]       <=        address_gen[5][1]                       ;
                address_gen[1][6]       <=        address_gen[6][1]                       ;
                address_gen[1][7]       <=        address_gen[7][1]                       ;
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
                        generated_rd_addr[a]<=   address_gen[addr_idx][a];
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
            rd_ena_d                       <=    1'b0               ;
        end 
        else begin
            rd_ena_d                       <=    rd_ena             ;
        end
    end

    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            addr_idx_d                     <=    'b0                ;
        end 
        else begin
            if (rd_ena_d) begin
                addr_idx_d                 <=    addr_idx_d + 1     ;
            end 
            else begin
                addr_idx_d                 <=    addr_idx_d         ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            pixel_image[1][1]              <=    'b0                ;
            pixel_image[1][2]              <=    'b0                ;
            pixel_image[1][3]              <=    'b0                ;
            pixel_image[1][4]              <=    'b0                ;
            pixel_image[2][1]              <=    'b0                ;
            pixel_image[2][2]              <=    'b0                ;
            pixel_image[2][3]              <=    'b0                ;
            pixel_image[2][4]              <=    'b0                ;
            pixel_image[3][1]              <=    'b0                ;
            pixel_image[3][2]              <=    'b0                ;
            pixel_image[3][3]              <=    'b0                ;
            pixel_image[3][4]              <=    'b0                ;
            pixel_image[4][1]              <=    'b0                ;
            pixel_image[4][2]              <=    'b0                ;
            pixel_image[4][3]              <=    'b0                ;
            pixel_image[4][4]              <=    'b0                ;
        end
        else begin
            if (rd_ena_d) begin
                case (addr_idx_d)
                    0:  begin
                        pixel_image[1][1]  <=    d_in_proc[0]       ;            
                        pixel_image[1][2]  <=    d_in_proc[1]       ;            
                        pixel_image[1][3]  <=    d_in_proc[2]       ;            
                        pixel_image[1][4]  <=    d_in_proc[3]       ;            
                        pixel_image[2][1]  <=    d_in_proc[4]       ;            
                        pixel_image[2][2]  <=    d_in_proc[5]       ;            
                        pixel_image[2][3]  <=    d_in_proc[6]       ;            
                        pixel_image[2][4]  <=    d_in_proc[7]       ;
                    end
                    1:  begin
                        pixel_image[3][1]  <=    d_in_proc[0]       ;            
                        pixel_image[3][2]  <=    d_in_proc[1]       ;            
                        pixel_image[3][3]  <=    d_in_proc[2]       ;            
                        pixel_image[3][4]  <=    d_in_proc[3]       ;            
                        pixel_image[4][1]  <=    d_in_proc[4]       ;            
                        pixel_image[4][2]  <=    d_in_proc[5]       ;            
                        pixel_image[4][3]  <=    d_in_proc[6]       ;            
                        pixel_image[4][4]  <=    d_in_proc[7]       ;
                    end
                endcase
            end 
            else begin
                pixel_image[1][1]          <=    pixel_image[1][1]  ;
                pixel_image[1][2]          <=    pixel_image[1][2]  ;
                pixel_image[1][3]          <=    pixel_image[1][3]  ;
                pixel_image[1][4]          <=    pixel_image[1][4]  ;
                pixel_image[2][1]          <=    pixel_image[2][1]  ;
                pixel_image[2][2]          <=    pixel_image[2][2]  ;
                pixel_image[2][3]          <=    pixel_image[2][3]  ;
                pixel_image[2][4]          <=    pixel_image[2][4]  ;
                pixel_image[3][1]          <=    pixel_image[3][1]  ;
                pixel_image[3][2]          <=    pixel_image[3][2]  ;
                pixel_image[3][3]          <=    pixel_image[3][3]  ;
                pixel_image[3][4]          <=    pixel_image[3][4]  ;
                pixel_image[4][1]          <=    pixel_image[4][1]  ;
                pixel_image[4][2]          <=    pixel_image[4][2]  ;
                pixel_image[4][3]          <=    pixel_image[4][3]  ;
                pixel_image[4][4]          <=    pixel_image[4][4]  ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            x                   <=   3'd1                ;
        end
        else begin
            if (c_st == data_proc) begin
                if (x == 3'd3) begin
                    x           <=   3'd1                ;
                end
                else begin
                    x           <=   x + 2               ;
                end
            end
            else begin
                x               <=   x                   ;
            end
        end
    end

    genvar idx ;

    generate
        for (idx = 0;idx < 4 ; idx = idx + 1) begin

            U6_0_0_Calculator u_U6_0_0_Calculator0(
                .clk                                (clk                       ),
                .rst                                (rst                       ),
                .d_valid                            ((c_st == data_proc)       ),
                .din_0                              (pixel_image[x  ][idx+1]     ),
                .din_1                              (pixel_image[x  ][idx+1]     ),
                .din_2                              (pixel_image[x  ][idx+1]     ),
                .din_3                              (pixel_image[x  ][idx+1]     ),
                .din_4                              (pixel_image[x  ][idx+1]     ),
                .din_5                              (pixel_image[x  ][idx+1]     ),
                .din_6                              (pixel_image[x  ][idx+1]     ),
                .din_7                              (pixel_image[x  ][idx+1]     ),
                .din_8                              (pixel_image[x  ][idx+1]     ),
                .d_out                              (d_out      [idx]            ),
                .d_out_valid                        (d_out_vld  [idx]            ) 
                );
            
                U6_0_0_Calculator u_U6_0_0_Calculator1(
                .clk                                (clk                       ),
                .rst                                (rst                       ),
                .d_valid                            ((c_st == data_proc)       ),
                .din_0                              (pixel_image[x+1][idx+1]     ),
                .din_1                              (pixel_image[x+1][idx+1]     ),
                .din_2                              (pixel_image[x+1][idx+1]     ),
                .din_3                              (pixel_image[x+1][idx+1]     ),
                .din_4                              (pixel_image[x+1][idx+1]     ),
                .din_5                              (pixel_image[x+1][idx+1]     ),
                .din_6                              (pixel_image[x+1][idx+1]     ),
                .din_7                              (pixel_image[x+1][idx+1]     ),
                .din_8                              (pixel_image[x+1][idx+1]     ),
                .d_out                              (d_out      [idx+4]          ),
                .d_out_valid                        (d_out_vld  [idx+4]          ) 
                );

        end
    endgenerate




    always @(posedge clk ) begin
        if (rst | finish_clr) begin
            addr_out_idx                <=  'b0                                 ;
        end 
        else begin
            if (d_out_vld[0]) begin
                addr_out_idx            <=  addr_out_idx + 1                    ;
            end
            else begin
                addr_out_idx            <=  addr_out_idx                        ;
            end
        end
    end

    genvar c;

    generate
        for (c = 0;c < CHANNEL_NUM ;c = c + 1) begin
            assign   d_out_addr[c]       =  address_gen[addr_out_idx][c]        ;
        end
    endgenerate


    assign   algo_finish_flag            = (addr_out_idx && d_out_vld[0])       ;

endmodule
