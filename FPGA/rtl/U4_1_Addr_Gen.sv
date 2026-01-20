`timescale 1ns / 1ps
//****************************************VSCODE PLUG-IN**********************************//
//----------------------------------------------------------------------------------------
// IDE :                   VSCODE     
// VSCODE plug-in version: Verilog-Hdl-Format-3.3.20250120
// VSCODE plug-in author : Jiang Percy
//----------------------------------------------------------------------------------------
//****************************************Copyright (c)***********************************//
// Copyright(C)            Please Write Company name
// All rights reserved     
// File name:              
// Last modified Date:     2025/01/23 16:48:09
// Last Version:           V1.0
// Descriptions:           
//----------------------------------------------------------------------------------------
// Created by:             Please Write You Name 
// Created date:           2025/01/23 16:48:09
// mail      :             Please Write mail 
// Version:                V1.0
// TEXT NAME:              U7_1_0_1_0_Addr_Gen.v
// PATH:                   D:\EDA_Work_Space\CCIC_ISP_OV5640\CCIC_ISP_OV5640.srcs\sources_1\new\U7_1_0_1_0_Addr_Gen.v
// Descriptions:           
//                         
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module U4_1_Addr_Gen #(
    parameter                 MB_WIDTH                    = 160   ,                
    parameter                 DS_WIDTH                    = 80    ,                
    parameter                 MB_HEIGHT                   = 120   ,                
    parameter                 DS_HEIGHT                   = 60               

)
(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       ena                         ,
    input                     [   1: 0]         gen_type                    ,

    input                     [  14: 0]         central_address             ,

    output reg                [  14: 0]         address_0                   ,
    output reg                                  address_0_ena               ,
    output reg                [  15: 0]         site_0                      ,

    output reg                [  14: 0]         address_1                   ,
    output reg                                  address_1_ena               ,
    output reg                [  15: 0]         site_1                      ,


    output reg                [  14: 0]         address_2                   ,
    output reg                                  address_2_ena               ,
    output reg                [  15: 0]         site_2                      ,

    output reg                [  14: 0]         address_3                   ,
    output reg                                  address_3_ena               ,
    output reg                [  15: 0]         site_3                      ,

    output reg                [  14: 0]         address_4                   ,
    output reg                                  address_4_ena               ,
    output reg                [  15: 0]         site_4                      ,

    output reg                [  14: 0]         address_5                   ,
    output reg                                  address_5_ena               ,
    output reg                [  15: 0]         site_5                      ,

    output reg                [  14: 0]         address_6                   ,
    output reg                                  address_6_ena               ,
    output reg                [  15: 0]         site_6                      ,

    output reg                [  14: 0]         address_7                   ,
    output reg                                  address_7_ena               ,
    output reg                [  15: 0]         site_7                      ,

    output reg                [  14: 0]         address_8                   ,
    output reg                                  address_8_ena               ,
    output reg                [  15: 0]         site_8                      ,

    output wire                                 cal_finish_flag             ,
    input                                       flag_clr                     

);



    reg                [   7: 0]        row                                 ;//
    reg                [   7: 0]        column                              ;
    reg                                 flag1                               ;
    reg                                 flag2                               ;


    assign     cal_finish_flag          = flag1 & flag2                     ;

    always @(posedge clk ) begin
        if (rst || flag_clr) begin
            row                     <= 'b0                                  ;
            column                  <= 'b0                                  ;
            flag1                   <= 'b0                                  ;
        end
        else begin
            if (ena) begin
                flag1               <= 1'b1                                 ;
                if (gen_type == 2'b00) begin//�������ǿ�ƥ��ͼ����,Ҫת���ɶ�Ӧ�²���������
                    row             <= (central_address / MB_WIDTH) >> 1    ;
                    column          <= (central_address % MB_WIDTH) >> 1    ;
                end
                else if (gen_type == 2'b11 || gen_type == 2'b01) begin
                    row             <= (central_address / DS_WIDTH)         ;
                    column          <= (central_address % DS_WIDTH)         ;
                end
                else begin//���������²���ͼ����,ת�����ϲ�������
                    row             <= (central_address / DS_WIDTH) << 1    ;
                    column          <= (central_address % DS_WIDTH) << 1    ;
                end
            end 
            else begin
                flag1               <= flag1                                ;
                row                 <= row                                  ;
                column              <= column                               ;
            end
        end
    end



//****************************************************************************************//


always @(posedge clk ) begin
    if (rst || flag_clr) begin
        address_0_ena          <= 1'b0                                      ;
        address_0              <=  'b0                                      ;
        flag2                  <= 1'b0                                      ;
        site_0                 <=  'b0                                      ;
    end else begin
        if (flag1) begin
                flag2          <= 1'b1                                      ;
            case (gen_type)
                2'b00,2'b11: begin//9
                    address_0_ena  <= 1'b1                                  ;
                    address_0  <=  (row) * DS_WIDTH  + column               ;
                    site_0     <=  {row,column}                             ;
                end
                2'b01: begin//5
                    address_0_ena  <= 1'b1                                  ;
                    address_0  <=  (row) * DS_WIDTH  + column               ;
                    site_0     <=  {row,column}                             ;
                end
                2'b10: begin//4
                    address_0_ena  <= 1'b1                                  ;
                    address_0  <=  (row  * MB_WIDTH) + column               ;
                    site_0     <=  {row,column}                             ;
                end
                default: begin
                    address_0_ena  <= 1'b0                                  ;
                    address_0  <=  address_0                                ;
                end
            endcase
        end 
        else begin
            address_0_ena      <= 1'b0                                      ;
            address_0          <=  'b0                                      ;   
        end
    end
end

always @(posedge clk ) begin
    if (rst || flag_clr) begin
        address_1       <=  'b0                                             ;
        address_1_ena   <= 1'b0                                             ;
        site_1          <=  'b0                                             ;
    end else begin
        if (flag1) begin
            case (gen_type)
                2'b00,2'b11: begin//9
                    if (row < 2) begin
                        address_1_ena   <= 1'b0                             ;
                        address_1       <=  'b0                             ;
                        site_1          <=  'b0                             ;
                    end 
                    else begin
                        address_1_ena   <= 1'b1                             ;
                        address_1       <= (row - 2)* DS_WIDTH + column     ;
                        site_1          <=  {(row - 2),column}              ;
                    end
                end
                2'b01: begin//5
                    if (row == 'b0) begin
                        address_1_ena   <= 1'b0                             ;
                        address_1       <=  'b0                             ;
                        site_1          <=  'b0                             ;
                    end 
                    else begin
                        address_1_ena   <= 1'b1                             ;
                        address_1       <= (row - 1)* DS_WIDTH + column     ;
                        site_1          <=  {(row - 1),column}              ;
                    end               
                end
                2'b10: begin//4
                    address_1_ena       <= 1'b1                             ;
                    address_1           <=  (row * MB_WIDTH) +  (column + 1);
                    site_1              <=  {(row),(column + 1)}            ;
                end
                default: begin
                    address_1_ena       <= 1'b0                             ;
                    address_1           <=  address_1                       ;
                end
            endcase
        end 
        else begin
            address_1_ena       <= 1'b0                                     ;
            address_1          <=  'b0                                      ;   
        end
    end
end

always @(posedge clk ) begin
    if (rst || flag_clr) begin
        address_2       <=  'b0                                             ;
        address_2_ena   <= 1'b0                                             ;
        site_2          <=  'b0                                             ;
    end 
    else begin
        if (flag1) begin
            case (gen_type)
                2'b00,2'b11: begin//9
                    if ((row == 0) || (column == DS_WIDTH - 1)) begin
                        address_2_ena   <= 1'b0                             ;
                        address_2       <=  'b0                             ;
                    end 
                    else begin
                        address_2_ena   <= 1'b1                             ;
                        address_2       <= (row - 1) * DS_WIDTH + column + 1;
                        site_2          <=  {(row-1),(column + 1)}            ;
                    end
                end
                2'b01: begin//5
                    if (column == DS_WIDTH - 1) begin
                        address_2_ena   <= 1'b0                             ;
                        address_2       <=  'b0                             ;
                    end
                    else begin
                        address_2_ena   <= 1'b1                             ;
                        address_2       <= (row)* DS_WIDTH + column + 1     ;
                        site_2          <=  {(row),(column + 1)}            ;

                    end               
                end
                2'b10: begin//4
                        address_2_ena   <= 1'b1                             ;
                        address_2       <=  (row + 1)* MB_WIDTH + (column + 1);
                        site_2          <=  {(row + 1),(column + 1)}            ;
                end
                default: begin
                    address_2_ena <= 1'b0                                   ;
                    address_2  <=  address_2                                ;
                end
            endcase
        end 
        else begin
            address_2_ena      <= 1'b0                                      ;
            address_2          <=  'b0                                      ;   
        end
    end
end

always @(posedge clk ) begin
    if (rst || flag_clr) begin
        address_3       <=  'b0                                             ;
        address_3_ena   <= 1'b0                                             ;
        site_3          <=  'b0                                             ;
    end 
    else begin
        if (flag1) begin
            case (gen_type)
                2'b00,2'b11: begin//9
                    if ((column >= DS_WIDTH - 2)) begin
                        address_3_ena   <= 1'b0                             ;
                        address_3       <=  'b0                             ;
                    end 
                    else begin
                        address_3_ena   <= 1'b1                             ;
                        address_3       <= (row) * DS_WIDTH + column + 2    ;
                        site_3          <=  {(row),(column + 2)}            ;
                    end
                end
                2'b01: begin//5
                    if (row == DS_HEIGHT - 1) begin
                        address_3_ena   <= 1'b0                             ;
                        address_3       <=  'b0                             ;
                    end
                    else begin
                        address_3_ena   <= 1'b1                             ;
                        address_3       <= (row + 1)* DS_WIDTH + column     ;
                        site_3          <=  {(row + 1),(column )}           ;
                    end               
                end
                2'b10: begin//4
                    address_3_ena   <= 1'b1                                 ;
                    address_3       <=  ((row + 1)* DS_WIDTH ) + ((column)) ;
                    site_3          <=  {(row + 1),(column)}            ;
                end
                default: begin
                    address_3_ena   <= 1'b0                                 ;
                    address_3  <=  address_3                                ;
                end
            endcase
        end 
        else begin
            address_3_ena      <= 1'b0                                      ;
            address_3          <=  'b0                                      ;   
        end
    end
end

always @(posedge clk ) begin
    if (rst || flag_clr) begin
        address_4       <=  'b0                                             ;
        address_4_ena   <= 1'b0                                             ;
        site_4          <=  'b0                                             ;
    end 
    else begin
        if (flag1) begin
            case (gen_type)
                2'b00,2'b11: begin//9
                if ((row == DS_HEIGHT - 1) || (column == DS_WIDTH - 1)) begin
                        address_4_ena   <= 1'b0                             ;
                        address_4       <=  'b0                             ;
                    end 
                    else begin
                        address_4_ena   <= 1'b1                             ;
                        address_4       <= (row + 1) * DS_WIDTH + column + 1;
                        site_4          <=  {(row + 1),(column + 1)}            ;
                    end
                end
                2'b01: begin//5
                    if (column == 0) begin
                        address_4_ena   <= 1'b0                             ;
                        address_4       <=  'b0                             ;
                    end
                    else begin
                        address_4_ena   <= 1'b1                             ;
                        address_4       <= (row)* DS_WIDTH + column - 1     ;
                        site_4          <=  {(row ),(column - 1)}           ;
                    end               
                end
                default: begin
                    address_4_ena       <= 1'b0                             ;
                    address_4           <= address_4                        ;
                end
            endcase
        end 
        else begin
            address_4_ena      <= 1'b0                                      ;
            address_4          <=  'b0                                      ;   
        end
    end
end

always @(posedge clk ) begin
    if (rst || flag_clr) begin
        address_5       <=  'b0                                             ;
        address_5_ena   <= 1'b0                                             ;
        site_5          <= 'b0                                              ;
    end 
    else begin
        if (flag1) begin
            case (gen_type)
            2'b00,2'b11: begin//9
                if ((row >= DS_HEIGHT - 2)) begin
                        address_5_ena   <= 1'b0                             ;
                        address_5       <=  'b0                             ;
                    end 
                    else begin
                        address_5_ena   <= 1'b1                             ;
                        address_5       <= (row + 2) * DS_WIDTH + column    ;
                        site_3          <=  {(row + 2),(column)}            ;

                    end
                end
                default: begin
                    address_5_ena       <= 1'b0                             ;
                    address_5           <= address_5                        ;
                end
            endcase
        end
        else begin
            address_5_ena      <= 1'b0                                      ;
            address_5          <=  'b0                                      ;   
        end
    end
end

always @(posedge clk ) begin
    if (rst || flag_clr) begin
        address_6       <=  'b0                                             ;
        address_6_ena   <= 1'b0                                             ;
        site_6          <= 'b0                                              ;
    end 
    else begin
        if (flag1) begin
            case (gen_type)
            2'b00,2'b11: begin//9
                if ((row == DS_HEIGHT - 1) || (column == 0)) begin
                        address_6_ena   <= 1'b0                             ;
                        address_6       <=  'b0                             ;
                    end 
                    else begin
                        address_6_ena   <= 1'b1                             ;
                        address_6       <= (row + 1) * DS_WIDTH + column - 1;
                        site_6          <=  {(row + 1),(column-1)}            ;
                    end
                end
                default: begin
                    address_6_ena       <= 1'b0                             ;
                    address_6           <= address_6                        ;
                end
            endcase
        end
        else begin
            address_6_ena      <= 1'b0                                      ;
            address_6          <=  'b0                                      ;   
        end
    end
end

always @(posedge clk ) begin
    if (rst || flag_clr) begin
        address_7       <=  'b0                                             ;
        address_7_ena   <= 1'b0                                             ;
        site_7          <=  'b0                                            ;
    end
    else begin
        if (flag1) begin
            case (gen_type)
            2'b00,2'b11: begin//9
                if ((column < 2)) begin
                        address_7_ena   <= 1'b0                             ;
                        address_7       <=  'b0                             ;
                    end 
                    else begin
                        address_7_ena   <= 1'b1                             ;
                        address_7       <= (row) * DS_WIDTH + column - 2    ;
                        site_7          <=  {(row),(column - 2)}            ;
                    end
                end
                default: begin
                    address_7_ena       <= 1'b0                             ;
                    address_7           <= address_7                        ;
                end
            endcase
        end
        else begin
            address_7_ena      <= 1'b0                                      ;
            address_7          <=  'b0                                      ;   
        end
    end
end


always @(posedge clk ) begin
    if (rst || flag_clr) begin
        address_8                       <=  'b0                             ;
        address_8_ena                   <= 1'b0                             ;
        site_8                          <=  'b0                             ;
    end
    else begin
        if (flag1) begin
            case (gen_type)
            2'b00,2'b11: begin//9
                if ((column == 0) || (row == 0)) begin
                        address_8_ena   <= 1'b0                             ;
                        address_8       <=  'b0                             ;
                    end 
                    else begin
                        address_8_ena   <= 1'b1                             ;
                        address_8       <= (row - 1) * DS_WIDTH + column - 1;
                        site_8          <=  {(row - 1),(column - 1)}        ;
                    end
                end
                default: begin
                    address_8_ena       <= 1'b0                             ;
                    address_8           <= address_8                        ;
                end
            endcase
        end
        else begin
            address_8_ena               <= 1'b0                             ;
            address_8                   <=  'b0                             ;   
        end
    end
end

//****************************************************************************************//




endmodule