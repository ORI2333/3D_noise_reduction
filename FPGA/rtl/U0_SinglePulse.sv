`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/01/21 17:01:17
// Design Name: 
// Module Name: U7_1_0_4_PulseGenerate
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


module U0_SinglePulse(
    input                                       clk                         ,
    input                                       rst                         ,
    input                                       bi_dir                      ,
    input                                       pos_dir                     ,
    input                                       neg_dir                     ,

    output wire                                 bi_pulse                    ,
    output wire                                 pos_pulse                   ,
    output wire                                 neg_pulse                    

    );

    reg                                         ena0_d1                     ;
    reg                                         ena1_d1                     ;
    reg                                         ena2_d1                     ;




    assign                              bi_pulse      =  ena0_d1  ^ bi_dir  ;
    assign                              pos_pulse     = ~ena1_d1  & pos_dir ;
    assign                              neg_pulse     = ~neg_dir  & ena2_d1 ;





    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ena0_d1      <=      1'b0        ;
            ena1_d1      <=      1'b0        ;
            ena2_d1      <=      1'b0        ;
        end
        else begin
            ena0_d1      <=      bi_dir      ;
            ena1_d1      <=      pos_dir     ;
            ena2_d1      <=      neg_dir     ;
        end
    end     

endmodule
